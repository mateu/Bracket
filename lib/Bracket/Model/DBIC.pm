package Bracket::Model::DBIC;

use strict;
use base 'Catalyst::Model::DBIC::Schema';
use List::Util qw( max sum );
use Time::HiRes qw/ time /;

__PACKAGE__->config(schema_class => 'Bracket::Schema',);

=head2 update_points

SQL update of points that is way faster than player_points action in Admin.
DRAWBACK: only tested on MySQL, may be MySQL specfic update.
SOLUTION: Find DBIC way of doing it?  Use sub-query.

Note: sqlite3 does not like the syntax on this update

=cut

sub update_points {
    my $self    = shift;
    my $storage = $self->schema->storage;
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
                with games_played as (
                    select pick.game, team.seed
                    from pick
                    join team
                    on pick.pick = team.id
                    where pick.player = 1
                )
                update game
                inner join games_played gp
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
                with round_out_info as (
                    select get_loser(game.id) as losing_team, game.round
                    from team
                        join pick on team.id = pick.pick
                        join game on pick.game = game.id
                    where pick.player = 1
                    and game.round = get_current_round()
                    and game.round > 1
                )
                update team
                inner join round_out_info roi
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
            $previous_time = $current_time;

            my $total_time = sum values %times;
	    $total_time = sprintf("%.1f", 1000*$total_time);
            my @stats = map { $_ . ': ' . sprintf("%.1f", 1000*$times{$_}) } sort {$times{$b} <=> $times{$a}} keys %times;
	    unshift(@stats, "<u>total time: $total_time</u>");
            my $stats = join('<br>', @stats);
            return $stats;
        }
    );
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
                    and game in (15, 30, 45, 60, 61, 62, 63)
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

Count up how many picks a player has made in the final 4 (3 total).
Displayed on Players home page.

=cut

sub count_final4_picks {
    my ($self, $player_id) = @_;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select count(*) from player
            join pick on player.id = pick.player
            where pick.game > 60
            and player.id = ?
            ;'
            );
            $sth->execute($player_id) or die $sth->errstr;
            
            return $sth->fetchall_arrayref->[0]->[0];
        }
    );
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
