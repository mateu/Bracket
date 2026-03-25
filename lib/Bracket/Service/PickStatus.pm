package Bracket::Service::PickStatus;

use strict;
use warnings;

sub player_picks {
    my ($class, $schema, $player_id) = @_;
    return [] if !$schema || !$player_id;

    return [
        $schema->resultset('Pick')->search(
            { player => $player_id },
            { prefetch => [qw/game pick/] }
        )->all
    ];
}

sub pick_map_from_rows {
    my ($class, $pick_rows) = @_;
    $pick_rows ||= [];

    my %pick_map = map { $_->game->id => $_->pick } @{$pick_rows};
    return \%pick_map;
}

sub winning_pick_ids {
    my ($class, $schema) = @_;
    return {} if !$schema;

    my %winning = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => 1 })->all;
    return \%winning;
}

sub classify_pick_rows {
    my ($class, $schema, $pick_rows, $winning_pick_ids) = @_;
    $pick_rows ||= [];
    $winning_pick_ids ||= $class->winning_pick_ids($schema);

    my %class_for;
    foreach my $player_pick (@{$pick_rows}) {
        my $game_id = $player_pick->game->id;
        my $winner_team_id = $winning_pick_ids->{$game_id};

        if (defined $winner_team_id) {
            $class_for{$game_id} = $winner_team_id == $player_pick->pick->id ? 'in' : 'out';
            next;
        }

        if ($player_pick->game->round >= $player_pick->pick->round_out) {
            $class_for{$game_id} = 'out';
            next;
        }

        $class_for{$game_id} = 'pending';
    }

    return \%class_for;
}

1;
