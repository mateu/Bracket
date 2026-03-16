package Bracket::Service::BracketValidator;

use strict;
use warnings;

sub validate_region_payload {
    my ($class, $schema, $player_id, $region_id, $params) = @_;

    return { ok => 0, errors => ['Missing schema'] } if !$schema;
    return { ok => 0, errors => ['Invalid player id'] } if !$player_id;
    return { ok => 0, errors => ['Invalid region id'] } if !$region_id;

    my ($pick_map, $parse_errors) = _extract_pick_map($params);
    return { ok => 0, errors => $parse_errors } if @{$parse_errors};

    my $min_game = 1 + 15 * ($region_id - 1);
    my $max_game = 15 + 15 * ($region_id - 1);

    my @errors;
    my %existing = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => $player_id })->all;

    foreach my $game_id (sort { $a <=> $b } keys %{$pick_map}) {
        my $team_id = $pick_map->{$game_id};

        if ($game_id < $min_game || $game_id > $max_game) {
            push @errors, "Game ${game_id} is outside region ${region_id}";
            next;
        }

        push @errors, _validate_pick_for_game($schema, $game_id, $team_id, $region_id, $pick_map, \%existing);
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

    my %allowed_games = map { $_ => 1 } (61, 62, 63);
    my @errors;
    my %existing = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => $player_id })->all;

    foreach my $game_id (sort { $a <=> $b } keys %{$pick_map}) {
        my $team_id = $pick_map->{$game_id};

        if (!$allowed_games{$game_id}) {
            push @errors, "Game ${game_id} is not a Final Four game";
            next;
        }

        push @errors, _validate_pick_for_game($schema, $game_id, $team_id, undef, $pick_map, \%existing);
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

sub _validate_pick_for_game {
    my ($schema, $game_id, $team_id, $region_id, $pick_map, $existing) = @_;

    my $game = $schema->resultset('Game')->find({ id => $game_id });
    return "Game ${game_id} not found" if !$game;

    my $team = $schema->resultset('Team')->find({ id => $team_id });
    return "Team ${team_id} not found" if !$team;

    if (defined $region_id && $team->region->id != $region_id) {
        return "Team ${team_id} is not in region ${region_id}";
    }

    # Round 1 teams are fixed in game_team_graph.
    if ($game->round == 1) {
        my @team_ids = map { $_->team } $schema->resultset('GameTeamGraph')->search({ game => $game_id })->all;
        my %allowed = map { $_ => 1 } @team_ids;
        return "Team ${team_id} is not valid for round-1 game ${game_id}" if !$allowed{$team_id};
        return;
    }

    # Later rounds must be selected from parent-game winners.
    my @parents = map { $_->parent_game } $schema->resultset('GameGraph')->search({ game => $game_id })->all;
    return "Game ${game_id} has no parent mapping" if !@parents;

    my @allowed_team_ids;
    foreach my $parent_game (@parents) {
        my $winner = exists $pick_map->{$parent_game}
          ? $pick_map->{$parent_game}
          : $existing->{$parent_game};

        if (!defined $winner) {
            return "Cannot validate game ${game_id}: missing parent pick for game ${parent_game}";
        }

        push @allowed_team_ids, $winner;
    }

    my %allowed = map { $_ => 1 } @allowed_team_ids;
    return "Team ${team_id} is not a valid advancement for game ${game_id}" if !$allowed{$team_id};

    return;
}

1;
