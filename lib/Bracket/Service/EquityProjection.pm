package Bracket::Service::EquityProjection;

use strict;
use warnings;

use List::Util qw(max);

sub project {
    my ($class, $schema, $opts) = @_;
    $opts ||= {};

    return { error => 'Missing schema', player_projections => [] } if !$schema;

    my $iterations         = $opts->{iterations} || 2000;
    my $seed               = defined $opts->{seed} ? $opts->{seed} : 17;
    my $max_exact_outcomes = defined $opts->{max_exact_outcomes} ? $opts->{max_exact_outcomes} : 12;

    my @players = $schema->resultset('Player')->search(
        { active => 1, id => { '!=' => 1 } },
        { order_by => [qw/ last_name first_name id /] }
    )->all;

    my %player_by_id = map { $_->id => $_ } @players;
    my @player_ids = sort { $a <=> $b } keys %player_by_id;

    my @games = $schema->resultset('Game')->search({}, { order_by => [qw/ round id /] })->all;
    my %games_by_id = map {
        $_->id => {
            id         => $_->id,
            round      => $_->get_column('round'),
            winner     => $_->get_column('winner'),
            lower_seed => $_->get_column('lower_seed'),
        }
    } @games;
    my @ordered_game_ids = map { $_->id } @games;

    my %team_seed = map { $_->id => $_->seed } $schema->resultset('Team')->search({})->all;

    my %parents_by_game;
    foreach my $edge ($schema->resultset('GameGraph')->search({})->all) {
        push @{$parents_by_game{$edge->game}}, $edge->parent_game;
    }

    my %teams_by_game;
    foreach my $edge ($schema->resultset('GameTeamGraph')->search({})->all) {
        push @{$teams_by_game{$edge->game}}, $edge->team;
    }

    my %known_winner = map {
        $games_by_id{$_}{winner} ? ($_ => $games_by_id{$_}{winner}) : ()
    } keys %games_by_id;
    my @unknown_games = grep { !$known_winner{$_} } @ordered_game_ids;

    my %player_pick_by_game;
    @player_pick_by_game{@player_ids} = map { {} } @player_ids;

    my @all_picks = $schema->resultset('Pick')->search({
        player => { -in => \@player_ids },
    })->all;
    foreach my $pick (@all_picks) {
        my $player_id = $pick->player->id;
        my $game_id   = $pick->game->id;
        my $team_id   = $pick->pick->id;
        $player_pick_by_game{$player_id}{$game_id} = $team_id;
    }

    my $current_points = _score_players(
        \@player_ids,
        \%player_pick_by_game,
        \%known_winner,
        \%games_by_id,
        \%team_seed,
        \%parents_by_game,
        \%teams_by_game,
    );

    my $possible_winners = _possible_winners_by_game(
        \@ordered_game_ids,
        \%games_by_id,
        \%known_winner,
        \%parents_by_game,
        \%teams_by_game,
    );

    my $max_possible_points = _max_possible_points(
        \@player_ids,
        \%player_pick_by_game,
        $current_points,
        $possible_winners,
        \@ordered_game_ids,
        \%known_winner,
        \%games_by_id,
        \%team_seed,
        \%parents_by_game,
        \%teams_by_game,
    );

    my $mode = @unknown_games <= $max_exact_outcomes ? 'exhaustive' : 'monte_carlo';

    my (%first_share, %podium_share, %score_sum);
    my $simulations = 0;

    if ($mode eq 'exhaustive') {
        _enumerate_outcomes(
            unknown_games      => \@unknown_games,
            known_winner       => \%known_winner,
            games_by_id        => \%games_by_id,
            player_ids         => \@player_ids,
            player_pick_by_game => \%player_pick_by_game,
            team_seed          => \%team_seed,
            parents_by_game    => \%parents_by_game,
            teams_by_game      => \%teams_by_game,
            on_trial           => sub {
                my ($score_by_player) = @_;
                $simulations++;
                _accumulate_trial(
                    player_ids    => \@player_ids,
                    score_by_player => $score_by_player,
                    first_share   => \%first_share,
                    podium_share  => \%podium_share,
                    score_sum     => \%score_sum,
                );
            },
        );
    }
    else {
        # Use a local LCG PRNG seeded by $seed rather than reseeding Perl's
        # global rand(), which would make subsequent rand() calls in other parts
        # of the app (e.g. password-reset token generation) predictable within
        # the same worker process.  The LCG constants are the glibc defaults.
        # For small candidate arrays (typically 2 teams), the negligible modulo
        # bias is acceptable for this probabilistic simulation.
        my $prng_state = $seed;
        my $prng = sub {
            $prng_state = ($prng_state * 1664525 + 1013904223) % 2**32;
            return $prng_state;
        };
        for (1 .. $iterations) {
            my %winner = %known_winner;
            foreach my $game_id (@unknown_games) {
                my $candidates = _candidate_winners_for_game(
                    $game_id,
                    \%games_by_id,
                    \%winner,
                    \%parents_by_game,
                    \%teams_by_game,
                );
                next if !@{$candidates};
                my $winner = $candidates->[$prng->() % scalar @{$candidates}];
                $winner{$game_id} = $winner;
            }

            my $score_by_player = _score_players(
                \@player_ids,
                \%player_pick_by_game,
                \%winner,
                \%games_by_id,
                \%team_seed,
                \%parents_by_game,
                \%teams_by_game,
            );

            $simulations++;
            _accumulate_trial(
                player_ids      => \@player_ids,
                score_by_player => $score_by_player,
                first_share     => \%first_share,
                podium_share    => \%podium_share,
                score_sum       => \%score_sum,
            );
        }
    }

    $simulations ||= 1;

    my @rows;
    foreach my $player_id (@player_ids) {
        my $player = $player_by_id{$player_id};
        my $first_pct = 100 * (($first_share{$player_id} || 0) / $simulations);
        my $podium_pct = 100 * (($podium_share{$player_id} || 0) / $simulations);
        my $avg_score = ($score_sum{$player_id} || 0) / $simulations;

        push @rows, {
            player_id             => $player_id,
            player_name           => join(' ', grep { defined && $_ ne '' } $player->first_name, $player->last_name),
            current_points        => $current_points->{$player_id} || 0,
            max_possible_points   => $max_possible_points->{$player_id} || ($current_points->{$player_id} || 0),
            projected_first_pct   => sprintf('%.2f', $first_pct),
            projected_podium_pct  => sprintf('%.2f', $podium_pct),
            projected_score_avg   => sprintf('%.2f', $avg_score),
        };
    }

    @rows = sort {
           $b->{projected_first_pct} <=> $a->{projected_first_pct}
        || $b->{projected_podium_pct} <=> $a->{projected_podium_pct}
        || $b->{current_points} <=> $a->{current_points}
        || lc($a->{player_name}) cmp lc($b->{player_name})
    } @rows;

    return {
        engine            => $mode,
        simulations       => $simulations,
        seed              => $seed,
        unknown_games     => scalar @unknown_games,
        assumptions       => [
            'Each unresolved game is modeled as a 50/50 winner between the two surviving teams.',
            'No external team-strength odds are used in this first pass.',
            'Max Possible Points is an optimistic ceiling that treats future pick outcomes independently.',
        ],
        player_projections => \@rows,
    };
}

sub _enumerate_outcomes {
    my (%args) = @_;

    my $unknown_games = $args{unknown_games} || [];
    my $known_winner = $args{known_winner} || {};
    my $games_by_id = $args{games_by_id} || {};
    my $player_ids = $args{player_ids} || [];
    my $player_pick_by_game = $args{player_pick_by_game} || {};
    my $team_seed = $args{team_seed} || {};
    my $parents_by_game = $args{parents_by_game} || {};
    my $teams_by_game = $args{teams_by_game} || {};
    my $on_trial = $args{on_trial};

    my $walk;
    $walk = sub {
        my ($idx, $winner_ref) = @_;

        if ($idx >= @{$unknown_games}) {
            my $score_by_player = _score_players(
                $player_ids,
                $player_pick_by_game,
                $winner_ref,
                $games_by_id,
                $team_seed,
                $parents_by_game,
                $teams_by_game,
            );
            $on_trial->($score_by_player);
            return;
        }

        my $game_id = $unknown_games->[$idx];
        my $candidates = _candidate_winners_for_game(
            $game_id,
            $games_by_id,
            $winner_ref,
            $parents_by_game,
            $teams_by_game,
        );

        if (!@{$candidates}) {
            $walk->($idx + 1, $winner_ref);
            return;
        }

        foreach my $winner (@{$candidates}) {
            my %next_winner = (%{$winner_ref}, $game_id => $winner);
            $walk->($idx + 1, \%next_winner);
        }
    };

    $walk->(0, { %{$known_winner} });
}

sub _accumulate_trial {
    my (%args) = @_;
    my $player_ids = $args{player_ids} || [];
    my $score_by_player = $args{score_by_player} || {};
    my $first_share = $args{first_share} || {};
    my $podium_share = $args{podium_share} || {};
    my $score_sum = $args{score_sum} || {};

    my @scores = map { $score_by_player->{$_} || 0 } @{$player_ids};
    my $top = @scores ? max(@scores) : 0;
    my @leaders = grep { ($score_by_player->{$_} || 0) == $top } @{$player_ids};
    my $leader_share = @leaders ? (1 / @leaders) : 0;
    $first_share->{$_} += $leader_share foreach @leaders;

    my %group;
    foreach my $player_id (@{$player_ids}) {
        my $score = $score_by_player->{$player_id} || 0;
        push @{$group{$score}}, $player_id;
        $score_sum->{$player_id} += $score;
    }
    my @ranked_scores = sort { $b <=> $a } keys %group;

    my $slots = 3;
    foreach my $score (@ranked_scores) {
        last if $slots <= 0;
        my @group_players = @{$group{$score}};
        if (@group_players <= $slots) {
            $podium_share->{$_} += 1 foreach @group_players;
            $slots -= @group_players;
        }
        else {
            my $share = $slots / @group_players;
            $podium_share->{$_} += $share foreach @group_players;
            $slots = 0;
        }
    }
}

sub _score_players {
    my ($player_ids, $player_pick_by_game, $winner_by_game, $games_by_id, $team_seed, $parents_by_game, $teams_by_game) = @_;

    my %score_by_player = map { $_ => 0 } @{$player_ids};

    foreach my $player_id (@{$player_ids}) {
        my $pick_map = $player_pick_by_game->{$player_id} || {};

        foreach my $game_id (keys %{$pick_map}) {
            my $winner = $winner_by_game->{$game_id};
            next if !defined $winner;

            my $pick_team = $pick_map->{$game_id};
            next if $pick_team != $winner;

            my $game = $games_by_id->{$game_id};
            next if !$game;

            my $winner_seed = $team_seed->{$winner} || 0;
            my $lower_seed = _lower_seed_for_game(
                $game_id,
                $winner,
                $winner_by_game,
                $game,
                $team_seed,
                $parents_by_game,
                $teams_by_game,
            );

            $score_by_player{$player_id} += $game->{round} * (5 + $lower_seed * $winner_seed);
        }
    }

    return \%score_by_player;
}

sub _max_possible_points {
    my (
        $player_ids,
        $player_pick_by_game,
        $current_points,
        $possible_winners,
        $ordered_game_ids,
        $known_winner,
        $games_by_id,
        $team_seed,
        $parents_by_game,
        $teams_by_game
    ) = @_;

    my %max_points = map { $_ => ($current_points->{$_} || 0) } @{$player_ids};

    foreach my $player_id (@{$player_ids}) {
        my $pick_map = $player_pick_by_game->{$player_id} || {};

        foreach my $game_id (@{$ordered_game_ids}) {
            next if $known_winner->{$game_id};
            next if !exists $pick_map->{$game_id};

            my $picked_team = $pick_map->{$game_id};
            my %possible = map { $_ => 1 } @{$possible_winners->{$game_id} || []};
            next if !$possible{$picked_team};

            my $game = $games_by_id->{$game_id};
            next if !$game;

            my $seed = $team_seed->{$picked_team} || 0;
            my $optimistic_lower_seed = _optimistic_lower_seed_flag(
                $game_id,
                $picked_team,
                $game,
                $possible_winners,
                $team_seed,
                $parents_by_game,
                $teams_by_game,
            );

            $max_points{$player_id} += $game->{round} * (5 + $optimistic_lower_seed * $seed);
        }
    }

    return \%max_points;
}

sub _possible_winners_by_game {
    my ($ordered_game_ids, $games_by_id, $known_winner, $parents_by_game, $teams_by_game) = @_;

    my %possible;
    foreach my $game_id (@{$ordered_game_ids}) {
        if ($known_winner->{$game_id}) {
            $possible{$game_id} = [ $known_winner->{$game_id} ];
            next;
        }

        my $game = $games_by_id->{$game_id};
        if (!$game) {
            $possible{$game_id} = [];
            next;
        }

        if ($game->{round} == 1) {
            $possible{$game_id} = [ _dedupe(@{$teams_by_game->{$game_id} || []}) ];
            next;
        }

        my @parents = @{$parents_by_game->{$game_id} || []};
        my @candidate = _dedupe(map { @{$possible{$_} || []} } @parents);
        $possible{$game_id} = \@candidate;
    }

    return \%possible;
}

sub _candidate_winners_for_game {
    my ($game_id, $games_by_id, $winner_by_game, $parents_by_game, $teams_by_game) = @_;

    my $game = $games_by_id->{$game_id};
    return [] if !$game;

    if ($game->{round} == 1) {
        return [ _dedupe(@{$teams_by_game->{$game_id} || []}) ];
    }

    my @parents = @{$parents_by_game->{$game_id} || []};
    my @candidate;
    foreach my $parent_game (@parents) {
        next if !defined $winner_by_game->{$parent_game};
        push @candidate, $winner_by_game->{$parent_game};
    }
    return [ _dedupe(@candidate) ];
}

sub _lower_seed_for_game {
    my ($game_id, $winner_team, $winner_by_game, $game, $team_seed, $parents_by_game, $teams_by_game) = @_;

    return $game->{lower_seed} if defined $game->{winner} && defined $game->{lower_seed};

    my $winner_seed = $team_seed->{$winner_team} || 0;
    my $round = $game->{round} || 1;

    if ($round == 1) {
        return $winner_seed > 8 ? 1 : 0;
    }

    my $participants = _participants_for_game($game_id, $game, $winner_by_game, $parents_by_game, $teams_by_game);
    my @other = grep { $_ != $winner_team } @{$participants};
    return 0 if !@other;

    my $loser_seed = $team_seed->{$other[0]} || 0;
    return $winner_seed > $loser_seed ? 1 : 0;
}

sub _optimistic_lower_seed_flag {
    my ($game_id, $picked_team, $game, $possible_winners, $team_seed, $parents_by_game, $teams_by_game) = @_;

    my $picked_seed = $team_seed->{$picked_team} || 0;

    if (($game->{round} || 1) == 1) {
        my @teams = @{$teams_by_game->{$game_id} || []};
        my ($opponent) = grep { $_ != $picked_team } @teams;
        return 0 if !$opponent;
        return $picked_seed > ($team_seed->{$opponent} || 0) ? 1 : 0;
    }

    my @parents = @{$parents_by_game->{$game_id} || []};
    return 0 if @parents != 2;

    my ($left_parent, $right_parent) = @parents;
    my %left_possible = map { $_ => 1 } @{$possible_winners->{$left_parent} || []};
    my %right_possible = map { $_ => 1 } @{$possible_winners->{$right_parent} || []};

    my @opponents;
    if ($left_possible{$picked_team}) {
        @opponents = @{$possible_winners->{$right_parent} || []};
    }
    elsif ($right_possible{$picked_team}) {
        @opponents = @{$possible_winners->{$left_parent} || []};
    }
    else {
        return 0;
    }

    foreach my $opponent (@opponents) {
        my $opponent_seed = $team_seed->{$opponent} || 0;
        return 1 if $picked_seed > $opponent_seed;
    }
    return 0;
}

sub _participants_for_game {
    my ($game_id, $game, $winner_by_game, $parents_by_game, $teams_by_game) = @_;

    my $round = $game->{round} || 1;
    if ($round == 1) {
        return [ _dedupe(@{$teams_by_game->{$game_id} || []}) ];
    }

    my @parents = @{$parents_by_game->{$game_id} || []};
    my @teams;
    foreach my $parent_game (@parents) {
        next if !defined $winner_by_game->{$parent_game};
        push @teams, $winner_by_game->{$parent_game};
    }
    return [ _dedupe(@teams) ];
}

sub _dedupe {
    my @values = @_;
    my %seen;
    return grep { defined $_ && !$seen{$_}++ } @values;
}

1;
