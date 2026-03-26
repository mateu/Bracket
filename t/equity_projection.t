use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::EquityProjection;

my $schema = BracketTestSchema->init_schema(populate => 1);

# Keep the projection test focused on two active pool players.
$schema->resultset('Player')->update({ active => 0 });
my @pool_players = $schema->resultset('Player')->search(
    { id => { '!=' => 1 } },
    { order_by => 'id' }
)->all;

while (@pool_players < 2) {
    my $n = @pool_players + 1;
    my $new_player = $schema->resultset('Player')->create({
        username   => "equity_tester_$n",
        password   => 'test',
        first_name => "Equity$n",
        last_name  => 'Tester',
        email      => "equity$n\@example.test",
        active     => 0,
        points     => 0,
    });
    push @pool_players, $new_player;
}

my ($player_a, $player_b) = @pool_players[0, 1];
$player_a->update({ active => 1 });
$player_b->update({ active => 1 });

$schema->resultset('Pick')->delete;

# Force a near-complete board with one undecided game (game 9, round 2).
foreach my $game ($schema->resultset('Game')->search({})->all) {
    $game->update({
        winner     => 1,
        lower_seed => 0,
    });
}

$schema->resultset('Game')->find(1)->update({ winner => 1, lower_seed => 0 }); # team 1 beats team 2
$schema->resultset('Game')->find(2)->update({ winner => 3, lower_seed => 0 }); # team 3 beats team 4
$schema->resultset('Game')->find(9)->update({ winner => undef, lower_seed => 0 }); # unresolved

# Player 2 leads now, but player 3 has stronger upside on game 9.
for my $row (
    [$player_a->id, 1, 1],
    [$player_a->id, 2, 3],
    [$player_a->id, 9, 1],
    [$player_b->id, 1, 2],
    [$player_b->id, 2, 3],
    [$player_b->id, 9, 3],
) {
    $schema->resultset('Pick')->create({
        player => $row->[0],
        game   => $row->[1],
        pick   => $row->[2],
    });
}

my $exact = Bracket::Service::EquityProjection->project(
    $schema,
    {
        max_exact_outcomes => 12,
        iterations         => 500,
        seed               => 123,
    }
);

is($exact->{engine}, 'exhaustive', 'exhaustive engine used for one unresolved game');
is($exact->{simulations}, 2, 'two exact outcomes enumerated');

my %exact_by_player = map { $_->{player_id} => $_ } @{$exact->{player_projections}};

is($exact_by_player{$player_a->id}->{current_points}, 10, 'player A current points are computed from known winners');
is($exact_by_player{$player_a->id}->{max_possible_points}, 20, 'player A optimistic max points include unresolved game 9');
is($exact_by_player{$player_b->id}->{current_points}, 5, 'player B current points are computed from known winners');
is($exact_by_player{$player_b->id}->{max_possible_points}, 31, 'player B optimistic max points include upset bonus upside');

is($exact_by_player{$player_a->id}->{projected_first_pct}, '50.00', 'player A win probability is 50%');
is($exact_by_player{$player_b->id}->{projected_first_pct}, '50.00', 'player B win probability is 50%');
is($exact_by_player{$player_a->id}->{projected_podium_pct}, '100.00', 'player A podium probability is 100% in two-player pool');
is($exact_by_player{$player_b->id}->{projected_podium_pct}, '100.00', 'player B podium probability is 100% in two-player pool');

my $monte_a = Bracket::Service::EquityProjection->project(
    $schema,
    {
        max_exact_outcomes => 0,
        iterations         => 200,
        seed               => 777,
    }
);
my $monte_b = Bracket::Service::EquityProjection->project(
    $schema,
    {
        max_exact_outcomes => 0,
        iterations         => 200,
        seed               => 777,
    }
);

is($monte_a->{engine}, 'monte_carlo', 'monte carlo engine can be forced');
is($monte_a->{simulations}, 200, 'monte carlo runs requested number of iterations');
is_deeply($monte_a->{player_projections}, $monte_b->{player_projections}, 'fixed seed gives reproducible projections');

done_testing();
