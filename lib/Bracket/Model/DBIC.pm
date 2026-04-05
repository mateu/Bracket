package Bracket::Model::DBIC;

use strict;
use base 'Catalyst::Model::DBIC::Schema';
use List::Util qw( first max sum );
use Time::HiRes qw/ time /;
use Bracket::Service::BracketStructure;
use Bracket::Service::EquityProjection;

__PACKAGE__->config(schema_class => 'Bracket::Schema',);

=head2 update_points

SQL update of points that is way faster than player_points action in Admin.

On MySQL the original raw SQL path is used (fast, uses stored functions).
On all other drivers (SQLite, etc.) a portable DBIx::Class path is used.

B<Scoring formula>: C<round * (5 + lower_seed * seed)> for all rounds, where
C<round> is the raw round number (1–6). This matches the existing MySQL SQL
path. Note that C<Bracket::Controller::Admin::player_points> uses a special
multiplier of C<10> for the championship game (round 6) instead of C<6>; the
two code paths therefore produce different championship totals by design — the
fast C<update_points> path was authored before that multiplier was added and
has not been changed to avoid breaking existing stored scores.

=cut

sub update_points {
    my $self = shift;
    return _update_points_for_schema($self->schema);
}

sub _update_points_for_schema {
    my ($schema) = @_;
    my $driver = lc($schema->storage->dbh->{Driver}->{Name} || '');
    my $stats = $driver eq 'mysql'
      ? _update_points_mysql($schema)
      : _update_points_portable($schema);

    Bracket::Service::EquityProjection->refresh_default_cache($schema);
    return $stats;
}

sub _update_points_mysql {
    my ($schema) = @_;
    my $storage = $schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my %times;
            my $current_time = time();
            my $previous_time = $current_time;
            my $sth;

            # Record lower seed
            $sth = $dbh->prepare('
                update game
                inner join (
                    select pick.game, team.seed
                    from pick
                    join team
                    on pick.pick = team.id
                    where pick.player = 1
                ) gp
                on game.id = gp.game
                set lower_seed = CASE
                  WHEN game.round > 1 THEN (get_winner_seed(game.id) > get_loser_seed(game.id))
                  # First round is deterministic based on seed
                  ELSE gp.seed > 8
                  END
                  , game.winner = get_winner(game.id)
                where game.round = get_current_round()
                ;
            ');
            $sth->execute;
            $current_time = time();
            $times{lower_seed} = $current_time - $previous_time;
            $previous_time = $current_time;

            # Record round out
            # Do for round 1
            $sth = $dbh->prepare('
              update team
              set round_out = 1
              where 1 = get_current_round()
              and team.id in (select get_first_round_loser(game.id) from game where game.round = 1)
            ;
            ');
            $sth->execute;
            # Do for other rounds
            $sth = $dbh->prepare('
                update team
                inner join (
                    select get_loser(game.id) as losing_team, game.round
                    from team
                        join pick on team.id = pick.pick
                        join game on pick.game = game.id
                    where pick.player = 1
                    and game.round = get_current_round()
                    and game.round > 1
                ) roi
                on team.id = roi.losing_team
                set round_out = roi.round
               ;
            ');
            $sth->execute;
            $current_time = time();
            $times{round_out} = $current_time - $previous_time;
            $previous_time = $current_time;

            $sth = $dbh->prepare('
                insert into region_score
                select * from
                (select
                    player_picks.player,
                    team.region as region,
                    sum(game.round*(5 + game.lower_seed*team.seed)) as points
                from pick player_picks, pick perfect_picks, game game, team team
                where perfect_picks.pick = player_picks.pick
                and perfect_picks.game   = player_picks.game
                and player_picks.game    = game.id
                and player_picks.pick    = team.id
                and perfect_picks.player = 1
                group by player_picks.player, team.region
                ) as player_region_points
                on duplicate key update points=player_region_points.points
                ;'
            );
            $sth->execute;
            $current_time = time();
            $times{update_region_score} = $current_time - $previous_time;
            $previous_time = $current_time;

            $sth  = $dbh->prepare('
                update player player,
                (
                 select player, sum(points) as total_points from region_score
                 group by player
                ) region_scores
                set player.points = region_scores.total_points
                where player.id = region_scores.player;
            ');
            $sth->execute;
            $current_time = time();
            $times{update_player_points} = $current_time - $previous_time;

            return _format_update_stats(\%times);
        }
    );
}

sub _update_points_portable {
    my ($schema) = @_;
    my %times;
    my $current_time  = time();
    my $previous_time = $current_time;

    my @perfect_picks = $schema->resultset('Pick')->search(
        { player => 1 },
        { columns => [qw/game pick/] }
    )->all;
    my %perfect_winner_for_game = map {
        $_->get_column('game') => $_->get_column('pick')
    } @perfect_picks;

    my %games = map {
        $_->get_column('id') => $_
    } $schema->resultset('Game')->search({})->all;
    my %teams = map {
        $_->get_column('id') => $_
    } $schema->resultset('Team')->search({})->all;

    my %parent_games;
    foreach my $edge ($schema->resultset('GameGraph')->search({}, { order_by => [qw/game parent_game/] })->all) {
        push @{$parent_games{ $edge->get_column('game') }}, $edge->get_column('parent_game');
    }

    my %seeded_teams;
    foreach my $row ($schema->resultset('GameTeamGraph')->search({}, { order_by => [qw/game team/] })->all) {
        push @{$seeded_teams{ $row->get_column('game') }}, $row->get_column('team');
    }

    my $current_round = 0;
    foreach my $game_id (keys %perfect_winner_for_game) {
        my $game = $games{$game_id};
        next if !$game;
        my $round = $game->get_column('round');
        $current_round = $round if $round > $current_round;
    }

    if (!$current_round) {
        return _format_update_stats(\%times);
    }

    $schema->txn_do(sub {
        foreach my $game_id (sort { $a <=> $b } keys %games) {
            my $game = $games{$game_id};
            next if !$game || $game->get_column('round') != $current_round;
            my $winner_team_id = $perfect_winner_for_game{$game_id};
            next if !$winner_team_id;

            my $winner_team = $teams{$winner_team_id};
            next if !$winner_team;

            my $lower_seed = 0;
            if ($game->get_column('round') == 1) {
                $lower_seed = $winner_team->get_column('seed') > 8 ? 1 : 0;
            }
            else {
                my @parents = @{$parent_games{$game_id} || []};
                my @parent_winners = map { $perfect_winner_for_game{$_} } grep { exists $perfect_winner_for_game{$_} } @parents;
                my $loser_team_id = first { defined $_ && $_ != $winner_team_id } @parent_winners;
                if (defined $loser_team_id && $teams{$loser_team_id}) {
                    $lower_seed = $winner_team->get_column('seed') > $teams{$loser_team_id}->get_column('seed') ? 1 : 0;
                }
            }

            $game->update({
                winner     => $winner_team_id,
                lower_seed => $lower_seed,
            });
        }
    });
    $current_time = time();
    $times{lower_seed} = $current_time - $previous_time;
    $previous_time = $current_time;

    $schema->txn_do(sub {
        foreach my $game_id (sort { $a <=> $b } keys %games) {
            my $game = $games{$game_id};
            next if !$game || $game->get_column('round') != $current_round;
            my $winner_team_id = $perfect_winner_for_game{$game_id};
            next if !$winner_team_id;

            my $loser_team_id;
            if ($current_round == 1) {
                my @team_ids = @{$seeded_teams{$game_id} || []};
                $loser_team_id = first { $_ != $winner_team_id } @team_ids;
            }
            else {
                my @parents = @{$parent_games{$game_id} || []};
                my @parent_winners = map { $perfect_winner_for_game{$_} } grep { exists $perfect_winner_for_game{$_} } @parents;
                $loser_team_id = first { defined $_ && $_ != $winner_team_id } @parent_winners;
            }

            next if !defined $loser_team_id || !$teams{$loser_team_id};
            $teams{$loser_team_id}->update({ round_out => $current_round });
        }
    });
    $current_time = time();
    $times{round_out} = $current_time - $previous_time;
    $previous_time = $current_time;

    my %points_for;
    foreach my $pick ($schema->resultset('Pick')->search({}, { prefetch => [qw/game pick/] })->all) {
        my $game_id = $pick->get_column('game');
        my $winner_team_id = $perfect_winner_for_game{$game_id};
        next if !defined $winner_team_id || $winner_team_id != $pick->get_column('pick');

        my $game_row = $pick->game;
        my $team_row = $pick->pick;
        my $points_for_pick = $game_row->get_column('round') *
          (5 + $game_row->get_column('lower_seed') * $team_row->get_column('seed'));
        $points_for{$pick->get_column('player')}{ $team_row->get_column('region') } += $points_for_pick;
    }

    $schema->txn_do(sub {
        foreach my $player ($schema->resultset('Player')->search({})->all) {
            my $player_id = $player->get_column('id');
            foreach my $region_id (1 .. 4) {
                my $points = $points_for{$player_id}{$region_id} || 0;
                $schema->resultset('RegionScore')->update_or_create({
                    player => $player_id,
                    region => $region_id,
                    points => $points,
                });
            }
        }
    });
    $current_time = time();
    $times{update_region_score} = $current_time - $previous_time;
    $previous_time = $current_time;

    $schema->txn_do(sub {
        foreach my $player ($schema->resultset('Player')->search({})->all) {
            my $player_id = $player->get_column('id');
            my $total_points = 0;
            foreach my $region_id (1 .. 4) {
                $total_points += $points_for{$player_id}{$region_id} || 0;
            }
            $player->update({ points => $total_points });
        }
    });
    $current_time = time();
    $times{update_player_points} = $current_time - $previous_time;

    return _format_update_stats(\%times);
}

sub _format_update_stats {
    my ($times) = @_;
    my $total_time = sum(values %{$times}) // 0;
    $total_time = sprintf('%.1f', 1000 * $total_time);
    my @stats = map {
        $_ . ': ' . sprintf('%.1f', 1000 * ($times->{$_} // 0))
    } sort { ($times->{$b} // 0) <=> ($times->{$a} // 0) } keys %{$times};
    unshift(@stats, "<u>total time: $total_time</u>");
    return join('<br>', @stats);
}

=heads2 count_region_picks

Count up how many picks a player has made for each region.
Displayed on Player home page.

=cut

sub count_region_picks {
    my ($self, $player_id) = @_;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select region.id, count(*) from pick
            join team on pick.pick = team.id
            join region on team.region = region.id
            join game on pick.game = game.id
            where game.round < 5 and player = ?
            group by region.id
            ;'
            );
            $sth->execute($player_id) or die $sth->errstr;;
            my $picks_per_region = { 1 => 0, 2 => 0, 3 => 0, 4 => 0 };
            my $result = $sth->fetchall_arrayref;
            foreach my $row (@{$result}) {
                $picks_per_region->{$row->[0]} = $row->[1];
            }
            return $picks_per_region;
        }
    );
}

=heads2 count_player_picks

Count up how many picks a player has made out of the total (63).
Displayed on All Players home page.

=cut

sub count_player_picks {
    my ($self) = @_;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select player.id, count(*) from player
            join pick on player.id = pick.player
            group by player.id
            ;'
            );
            $sth->execute() or die $sth->errstr;
            my $picks_per_player = {};
            my $result = $sth->fetchall_arrayref;
            foreach my $row (@{$result}) {
                $picks_per_player->{$row->[0]} = $row->[1];
            }
            return $picks_per_player;
        }
    );
}

=heads2 count_player_picks_correct

Count up how many picks a player has made correct so far.
Displayed on All Players home page.

=cut

sub count_player_picks_correct {
    my $self = shift;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select player_picks.player, count(*)
              from pick player_picks, pick perfect_picks, game game, team team
             where perfect_picks.pick   = player_picks.pick 
               and perfect_picks.game   = player_picks.game 
               and player_picks.game    = game.id
               and player_picks.pick    = team.id
               and perfect_picks.player = 1
          group by player_picks.player
          ;'
          );
          $sth->execute() or die $sth->errstr;
          my $picks_per_player = {};
          my $result = $sth->fetchall_arrayref;
          foreach my $row (@{$result}) {
              $picks_per_player->{$row->[0]} = $row->[1];
          }
          my $max_correct = max map { $picks_per_player->{$_} } grep { $_ != 1 } keys %{$picks_per_player};
          return $picks_per_player, $max_correct;
        }
    );
}

=heads2 count_player_picks_upset

Count up how many upset picks a player has made correct so far.

=cut

sub count_player_picks_upset {
    my $self = shift;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select player_picks.player, count(*)
              from pick player_picks, pick perfect_picks, game game, team team
             where perfect_picks.pick   = player_picks.pick
               and perfect_picks.game   = player_picks.game
               and player_picks.game    = game.id
               and player_picks.pick    = team.id
               and perfect_picks.player = 1
               and game.lower_seed      = 1
          group by player_picks.player
          ;'
          );
          $sth->execute() or die $sth->errstr;
          my $upset_picks_per_player = {};
          my $result = $sth->fetchall_arrayref;
          foreach my $row (@{$result}) {
              $upset_picks_per_player->{$row->[0]} = $row->[1];
          }
          my $max_upsets = max map { $upset_picks_per_player->{$_} } grep { $_ != 1 } keys %{$upset_picks_per_player};
          return $upset_picks_per_player, $max_upsets;
        }
    );
}

=heads2 count_player_teams_left

Count how many teams a player has that are still playing and picked to advance
in the next game.

=cut

sub count_player_teams_left {
    my $self = shift;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
                with games_played as (
                    select p.game, g.round
                    from pick p
                    join game g
                    on p.game = g.id
                    where p.player = 1
                ),
                losing_teams as (
                    select
                    CASE 
                        WHEN round > 1 THEN get_loser(game)
                        ELSE get_first_round_loser(game)
                        END as team
                    from games_played
                ),
                games_remaining as (
                    select p.game
                    from pick p
                    where p.player = 24
                    and p.game not in (select game from games_played)
                ),
                player_teams_remaining as (
                    select player, pick
                    from pick
                    where game in (select game from games_remaining)
                    and pick not in (select team from losing_teams)
                    group by player, pick
                )
                select player, count(*) as teams_left
                from player_teams_remaining
                group by player
          ;'
          );
          $sth->execute() or die $sth->errstr;
          my $teams_left_per_player = {};
          my $result = $sth->fetchall_arrayref;
          foreach my $row (@{$result}) {
              $teams_left_per_player->{$row->[0]} = $row->[1];
          }
          my $max_left = max map { $teams_left_per_player->{$_} } grep { $_ != 1 } keys %{$teams_left_per_player};
          return $teams_left_per_player, $max_left;
        }
    );
}

=heads2 count_player_final4_teams_left

Count how many final 4 teams a player has that are still playing and picked to advance
in the next game.

=cut

sub count_player_final4_teams_left {
    my $self = shift;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
                with games_played as (
                    select p.game, g.round
                    from pick p
                    join game g
                    on p.game = g.id
                    where p.player = 1
                ),
                losing_teams as (
                    select
                    CASE
                        WHEN round > 1 THEN get_loser(game)
                        ELSE get_first_round_loser(game)
                        END as team
                    from games_played
                ),
                games_remaining as (
                    select p.game
                    from pick p
                    where p.player = 24
                    and p.game not in (select game from games_played)
                ),
                player_teams_remaining as (
                    select player, pick
                    from pick
                    where game in (select game from games_remaining)
                    and game in (
                        select id
                        from game
                        where round >= 4
                    )
                    and pick not in (select team from losing_teams)
                    group by player, pick
                )
                select player, count(*) as teams_left
                from player_teams_remaining
                group by player
          ;'
          );
          $sth->execute() or die $sth->errstr;
          my $final4_teams_left_per_player = {};
          my $result = $sth->fetchall_arrayref;
          foreach my $row (@{$result}) {
              $final4_teams_left_per_player->{$row->[0]} = $row->[1];
          }
          my $max_left = max map { $final4_teams_left_per_player->{$_} } grep { $_ != 1 } keys %{$final4_teams_left_per_player};
          return $final4_teams_left_per_player, $max_left;
        }
    );
}

=heads2 count_final4_picks

Count up how many picks a player has made in the final 4.
Displayed on Players home page.

=cut

sub count_final4_picks {
    my ($self, $player_id) = @_;
    return 0 if !defined $player_id;
    my $final4_game_ids = Bracket::Service::BracketStructure->final4_game_ids($self->schema) || [];
    my $where = {
        'me.player'  => $player_id,
        'game.round' => { '>=' => 5 },
    };

    if (@{$final4_game_ids}) {
        # Keep structure-derived IDs, but also allow round-derived final4 games
        # so this count remains correct when game IDs/topology drift.
        $where = {
            'me.player' => $player_id,
            -or => [
                'me.game'    => { -in => $final4_game_ids },
                'game.round' => { '>=' => 5 },
            ],
        };
    }

    return $self->schema->resultset('Pick')->search(
        $where,
        { join => 'game' }
    )->count;
}

=head1 NAME

Bracket::Model::DBIC - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<Bracket>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Bracket::Schema::DBIC>

=head1 AUTHOR

Mateu X Hunter

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
