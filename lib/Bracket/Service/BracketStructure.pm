package Bracket::Service::BracketStructure;

use strict;
use warnings;

sub describe_bracket {
    my ($class, $schema) = @_;
    return _derive_structure($schema);
}

sub final4_game_ids {
    my ($class, $schema) = @_;
    my $structure = $class->describe_bracket($schema);
    return $structure->{final4_game_ids};
}

sub region_winner_games_by_region {
    my ($class, $schema) = @_;
    my $structure = $class->describe_bracket($schema);
    return $structure->{region_winner_games_by_region};
}

sub game_routes {
    my ($class, $schema) = @_;
    my $structure = $class->describe_bracket($schema);
    return $structure->{game_routes};
}

sub pick_targets {
    my ($class, $schema) = @_;
    return {
        total_picks             => 0,
        final4_picks            => 0,
        region_picks_by_region  => {},
        topology_available      => 0,
    } if !$schema;

    my $structure = $class->describe_bracket($schema);
    my $parents_by_game = $structure->{parents_by_game} || {};
    my $topology_available = scalar(keys %{$parents_by_game}) ? 1 : 0;

    my %round_for_game = %{$structure->{round_for_game} || {}};
    foreach my $game ($schema->resultset('Game')->search({})->all) {
        my $game_id = $game->id;
        next if !defined $game_id;
        $round_for_game{$game_id} = $game->round;
    }

    my %region_picks_by_region;
    foreach my $game_id (sort { $a <=> $b } keys %round_for_game) {
        my $round = $round_for_game{$game_id};
        next if !defined $round || $round >= 5;
        my $region_id = _region_for_game($schema, $game_id, $parents_by_game, \%round_for_game);
        next if !defined $region_id;
        $region_picks_by_region{$region_id}++;
    }

    my @final4_game_ids = @{$structure->{final4_game_ids} || []};
    return {
        total_picks             => scalar(keys %round_for_game),
        final4_picks            => scalar(@final4_game_ids),
        region_picks_by_region  => $topology_available ? \%region_picks_by_region : {},
        topology_available      => $topology_available,
    };
}

sub _derive_structure {
    my ($schema) = @_;
    return {
        championship_game_id          => undef,
        semifinal_game_ids            => [],
        final4_game_ids               => [],
        region_winner_games_by_region => {},
        game_routes                   => {},
        round_for_game                => {},
        parents_by_game               => {},
    } if !$schema;

    my @edges = $schema->resultset('GameGraph')->search({})->all;
    return {
        championship_game_id          => undef,
        semifinal_game_ids            => [],
        final4_game_ids               => [],
        region_winner_games_by_region => {},
        game_routes                   => {},
        round_for_game                => {},
        parents_by_game               => {},
    } if !@edges;

    my (%parents_by_game, %children_by_parent, %game_ids);
    foreach my $edge (@edges) {
        my $game_id        = $edge->game;
        my $parent_game_id = $edge->parent_game;
        next if !defined $game_id || !defined $parent_game_id;
        push @{$parents_by_game{$game_id}},           $parent_game_id;
        push @{$children_by_parent{$parent_game_id}}, $game_id;
        $game_ids{$game_id}        = 1;
        $game_ids{$parent_game_id} = 1;
    }

    my %game_round = map {
        $_->id => $_->round
    } $schema->resultset('Game')->search({
        id => { -in => [keys %game_ids] },
    })->all;

    my @sink_games = grep { !exists $children_by_parent{$_} } keys %parents_by_game;
    return {
        championship_game_id          => undef,
        semifinal_game_ids            => [],
        final4_game_ids               => [],
        region_winner_games_by_region => {},
        game_routes                   => {},
        round_for_game                => \%game_round,
        parents_by_game               => \%parents_by_game,
    } if !@sink_games;

    my $championship_game_id = _highest_round_game_id(\%game_round, \@sink_games);
    return {
        championship_game_id          => undef,
        semifinal_game_ids            => [],
        final4_game_ids               => [],
        region_winner_games_by_region => {},
        game_routes                   => {},
        round_for_game                => \%game_round,
        parents_by_game               => \%parents_by_game,
    } if !defined $championship_game_id;

    my @semifinal_game_ids = sort { $a <=> $b } @{$parents_by_game{$championship_game_id} || []};
    my %region_final_game_ids = map { $_ => 1 } map { @{$parents_by_game{$_} || []} } @semifinal_game_ids;

    my %region_winner_games_by_region;
    foreach my $game_id (sort { $a <=> $b } keys %region_final_game_ids) {
        my $region_id = _region_for_game($schema, $game_id, \%parents_by_game, \%game_round);
        next if !defined $region_id;
        next if exists $region_winner_games_by_region{$region_id};
        $region_winner_games_by_region{$region_id} = $game_id;
    }

    my %final4_game_ids = map { $_ => 1 } (@semifinal_game_ids, $championship_game_id);
    my @final4_game_ids = sort { $a <=> $b } keys %final4_game_ids;

    # Build a game-routing map: source_game_id => target_game_id.
    my %game_routes;
    foreach my $sf_id (@semifinal_game_ids) {
        foreach my $rw_game_id (@{$parents_by_game{$sf_id} || []}) {
            next unless exists $region_final_game_ids{$rw_game_id};
            $game_routes{$rw_game_id} = $sf_id;
        }
        $game_routes{$sf_id} = $championship_game_id if defined $championship_game_id;
    }

    return {
        championship_game_id          => $championship_game_id,
        semifinal_game_ids            => \@semifinal_game_ids,
        final4_game_ids               => \@final4_game_ids,
        region_winner_games_by_region => \%region_winner_games_by_region,
        game_routes                   => \%game_routes,
        round_for_game                => \%game_round,
        parents_by_game               => \%parents_by_game,
    };
}

sub _highest_round_game_id {
    my ($game_round, $game_ids) = @_;
    my @scored = map {
        [$_, (defined $game_round->{$_} ? $game_round->{$_} : -1)]
    } @{$game_ids};

    @scored = sort {
        $b->[1] <=> $a->[1] || $b->[0] <=> $a->[0]
    } @scored;

    return $scored[0] ? $scored[0]->[0] : undef;
}

sub _region_for_game {
    my ($schema, $game_id, $parents_by_game, $game_round) = @_;

    my @round1_games = _round1_ancestor_games($game_id, $parents_by_game, $game_round);
    return undef if !@round1_games;

    my @seed_rows = $schema->resultset('GameTeamGraph')->search({
        game => { -in => \@round1_games },
    })->all;

    # Collect team IDs from the seed rows to avoid N+1 Team lookups.
    my %team_ids;
    foreach my $seed_row (@seed_rows) {
        my $team_id = $seed_row->team;
        next if !defined $team_id;
        $team_ids{$team_id} = 1;
    }

    my %regions;
    if (%team_ids) {
        my @teams = $schema->resultset('Team')->search(
            { 'me.id' => { -in => [ sort { $a <=> $b } keys %team_ids ] } },
            { prefetch => 'region' },
        )->all;

        foreach my $team (@teams) {
            next if !$team;
            my $region = $team->region;
            next if !$region;
            $regions{$region->id} = 1;
        }
    }

    my @region_ids = sort { $a <=> $b } keys %regions;
    return @region_ids == 1 ? $region_ids[0] : undef;
}

sub _round1_ancestor_games {
    my ($game_id, $parents_by_game, $game_round) = @_;

    my %seen;
    my @queue = ($game_id);
    my %round1;

    while (@queue) {
        my $current = shift @queue;
        next if $seen{$current}++;

        my $round = $game_round->{$current};
        if (defined $round && $round == 1) {
            $round1{$current} = 1;
            next;
        }

        push @queue, @{$parents_by_game->{$current} || []};
    }

    return sort { $a <=> $b } keys %round1;
}

1;
