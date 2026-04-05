package Bracket::Service::BracketValidator;

use strict;
use warnings;
use Bracket::Service::BracketStructure;

sub validate_region_payload {
    my ($class, $schema, $player_id, $region_id, $params) = @_;

    return { ok => 0, errors => ['Missing schema'] } if !$schema;
    return { ok => 0, errors => ['Invalid player id'] } if !$player_id;
    return { ok => 0, errors => ['Invalid region id'] } if !$region_id;

    my ($pick_map, $parse_errors) = _extract_pick_map($params);
    return { ok => 0, errors => $parse_errors } if @{$parse_errors};

    my $region_game_ids = _region_game_ids_for_region($schema, $region_id);

    my @errors;
    my %existing = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => $player_id })->all;
    my %effective = (%existing, %{$pick_map});

    my @changed_games;
    foreach my $game_id (sort { $a <=> $b } keys %{$pick_map}) {
        if (!$region_game_ids->{$game_id}) {
            push @errors, "Game ${game_id} is outside region ${region_id}";
            next;
        }
        push @changed_games, $game_id;
    }

    my $games_to_validate = _affected_games_in_scope(
        $schema,
        \@changed_games,
        sub {
            my ($game_id) = @_;
            return $region_game_ids->{$game_id};
        }
    );

    foreach my $game_id (sort { $a <=> $b } keys %{$games_to_validate}) {
        next if !exists $effective{$game_id};

        my $team_id = $effective{$game_id};
        push @errors, _validate_pick_for_game($schema, $game_id, $team_id, $region_id, \%effective);
    }

    @errors = grep { defined $_ && $_ ne '' } @errors;
    return @errors
      ? { ok => 0, errors => \@errors }
      : { ok => 1, normalized_picks => $pick_map };
}

sub validate_final4_payload {
    my ($class, $schema, $player_id, $params) = @_;

    return { ok => 0, errors => ['Missing schema'] } if !$schema;
    return { ok => 0, errors => ['Invalid player id'] } if !$player_id;

    my ($pick_map, $parse_errors) = _extract_pick_map($params);
    return { ok => 0, errors => $parse_errors } if @{$parse_errors};

    my $final4_game_ids = Bracket::Service::BracketStructure->final4_game_ids($schema);
    if (@{$final4_game_ids} != 3) {
        return { ok => 0, errors => ['Could not derive complete Final Four game structure'] };
    }

    my %allowed_games = map { $_ => 1 } @{$final4_game_ids};
    my @errors;
    my %existing = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => $player_id })->all;
    my %effective = (%existing, %{$pick_map});

    my @changed_games;
    foreach my $game_id (sort { $a <=> $b } keys %{$pick_map}) {
        if (!$allowed_games{$game_id}) {
            push @errors, "Game ${game_id} is not a Final Four game";
            next;
        }
        push @changed_games, $game_id;
    }

    my $games_to_validate = _affected_games_in_scope(
        $schema,
        \@changed_games,
        sub {
            my ($game_id) = @_;
            return $allowed_games{$game_id};
        }
    );

    foreach my $game_id (sort { $a <=> $b } keys %{$games_to_validate}) {
        next if !exists $effective{$game_id};

        my $team_id = $effective{$game_id};
        push @errors, _validate_pick_for_game($schema, $game_id, $team_id, undef, \%effective);
    }

    @errors = grep { defined $_ && $_ ne '' } @errors;
    return @errors
      ? { ok => 0, errors => \@errors }
      : { ok => 1, normalized_picks => $pick_map };
}

sub _extract_pick_map {
    my ($params) = @_;
    $params ||= {};

    my %pick_map;
    my @errors;

    foreach my $key (keys %{$params}) {
        next if !defined $key;
        next if $key !~ /^p(\d+)$/;

        my $game_id = $1;
        my $team_id = $params->{$key};

        if (!defined $team_id || $team_id !~ /^\d+$/) {
            push @errors, "Invalid team id for ${key}";
            next;
        }

        $pick_map{$game_id} = int($team_id);
    }

    return (\%pick_map, \@errors);
}

sub _region_game_ids_for_region {
    my ($schema, $region_id) = @_;

    my $region_winner_games = Bracket::Service::BracketStructure->region_winner_games_by_region($schema);
    my $region_winner_game_id = $region_winner_games->{$region_id};
    return _fallback_region_game_ids($region_id) if !$region_winner_game_id;

    my %parents_by_game;
    foreach my $edge ($schema->resultset('GameGraph')->search({})->all) {
        push @{$parents_by_game{$edge->game}}, $edge->parent_game;
    }

    my %allowed_games;
    my @queue = ($region_winner_game_id);
    while (@queue) {
        my $game_id = shift @queue;
        next if $allowed_games{$game_id}++;
        push @queue, @{$parents_by_game{$game_id} || []};
    }

    return \%allowed_games;
}

sub _fallback_region_game_ids {
    my ($region_id) = @_;

    my $min_game = 1 + 15 * ($region_id - 1);
    my $max_game = 15 + 15 * ($region_id - 1);
    return { map { $_ => 1 } ($min_game .. $max_game) };
}

sub _affected_games_in_scope {
    my ($schema, $changed_games, $is_in_scope) = @_;

    my %children_by_parent;
    foreach my $edge ($schema->resultset('GameGraph')->search({})->all) {
        push @{$children_by_parent{$edge->parent_game}}, $edge->game;
    }

    my %affected = map { $_ => 1 } @{$changed_games};
    my @queue = @{$changed_games};

    while (@queue) {
        my $current = shift @queue;
        foreach my $child (@{$children_by_parent{$current} || []}) {
            next if !$is_in_scope->($child);
            next if $affected{$child};
            $affected{$child} = 1;
            push @queue, $child;
        }
    }

    # Keep only in-scope games.
    foreach my $game_id (keys %affected) {
        delete $affected{$game_id} if !$is_in_scope->($game_id);
    }

    return \%affected;
}

sub _team_label {
    my ($team, $fallback_id) = @_;
    return "Team ${fallback_id}" if !$team;

    my $name = $team->name || "Team ${fallback_id}";
    my $seed = $team->seed;

    return defined $seed ? "${name} (seed ${seed})" : $name;
}

sub _validate_pick_for_game {
    my ($schema, $game_id, $team_id, $region_id, $effective) = @_;

    my $game = $schema->resultset('Game')->find({ id => $game_id });
    return "Game ${game_id} not found" if !$game;

    my $team = $schema->resultset('Team')->find({ id => $team_id });
    return "Team ${team_id} not found" if !$team;

    my $team_label = _team_label($team, $team_id);

    if (defined $region_id && $team->region->id != $region_id) {
        return "${team_label} is not in region ${region_id}";
    }

    # Round 1 teams are fixed in game_team_graph.
    if ($game->round == 1) {
        my @team_ids = map { $_->team } $schema->resultset('GameTeamGraph')->search({ game => $game_id })->all;
        my %allowed = map { $_ => 1 } @team_ids;
        return "${team_label} is not valid for round-1 game ${game_id}" if !$allowed{$team_id};
        return;
    }

    # Later rounds must be selected from parent-game winners.
    my @parents = map { $_->parent_game } $schema->resultset('GameGraph')->search({ game => $game_id })->all;
    return "Game ${game_id} has no parent mapping" if !@parents;

    my @allowed_team_ids;
    foreach my $parent_game (@parents) {
        my $winner = $effective->{$parent_game};

        if (!defined $winner) {
            return "Cannot validate game ${game_id}: missing parent pick for game ${parent_game}";
        }

        push @allowed_team_ids, $winner;
    }

    my %allowed = map { $_ => 1 } @allowed_team_ids;
    if (!$allowed{$team_id}) {
        my %seen;
        my @allowed_desc = map {
            my $allowed_team = $schema->resultset('Team')->find({ id => $_ });
            _team_label($allowed_team, $_);
        } grep { !$seen{$_}++ } @allowed_team_ids;

        my $allowed_text = @allowed_desc
          ? join(' or ', @allowed_desc)
          : 'unknown';

        my $round = $game->round;
        my $round_text = defined $round ? "round ${round}" : 'an unknown round';
        return "${team_label} is not a valid advancement for game ${game_id} (${round_text}). Allowed winners for game ${game_id} are ${allowed_text}";
    }

    return;
}

1;
