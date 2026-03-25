package Bracket::Service::Scoring;

use strict;
use warnings;

sub summarize_player {
    my ($class, $schema, $player_id, %opts) = @_;
    my $region_id = $opts{region_id};

    my %perfect_pick_for_game = _perfect_pick_map($schema);

    my @player_picks = $schema->resultset('Pick')->search(
        { player => $player_id },
        { prefetch => [qw/game pick/] }
    );

    my %class_for;
    my %picks;
    my %region_points;
    my $total_points = 0;

    foreach my $player_pick (@player_picks) {
        my $team = $player_pick->pick;
        my $game = $player_pick->game;

        next if defined $region_id && $team->get_column('region') != $region_id;

        my $game_id = $game->id;
        $picks{$game_id} = $team;

        my $status = $class->status_for_pick($player_pick, \%perfect_pick_for_game);
        $class_for{$game_id} = $status;

        next if $status ne 'in';

        my $points = $class->points_for_correct_pick($player_pick);
        $total_points += $points;
        $region_points{ $team->get_column('region') } += $points;
    }

    return {
        class_for     => \%class_for,
        picks         => \%picks,
        total_points  => $total_points,
        region_points => \%region_points,
    };
}

sub status_for_pick {
    my ($class, $player_pick, $perfect_pick_for_game) = @_;

    my $game_id = $player_pick->get_column('game');
    my $team_id = $player_pick->get_column('pick');

    if (exists $perfect_pick_for_game->{$game_id}) {
        return $perfect_pick_for_game->{$game_id} == $team_id ? 'in' : 'out';
    }

    my $round     = $player_pick->game->get_column('round');
    my $round_out = $player_pick->pick->get_column('round_out');
    return $round >= $round_out ? 'out' : 'pending';
}

sub points_for_correct_pick {
    my ($class, $player_pick) = @_;

    my $seed       = $player_pick->pick->get_column('seed');
    my $lower_seed = $player_pick->game->get_column('lower_seed') || 0;
    my $round      = $player_pick->game->get_column('round');

    my $multiplier = $round == 6 ? 10 : $round;
    return (5 + $seed * $lower_seed) * $multiplier;
}

sub _perfect_pick_map {
    my ($schema) = @_;

    my %perfect_pick_for_game;
    my $perfect_rs = $schema->resultset('Pick')->search(
        { player => 1 },
        { columns => [qw/game pick/] }
    );

    while (my $perfect_pick = $perfect_rs->next) {
        $perfect_pick_for_game{ $perfect_pick->get_column('game') } =
          $perfect_pick->get_column('pick');
    }

    return %perfect_pick_for_game;
}

1;
