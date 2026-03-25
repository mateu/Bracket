use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::BracketValidator;
use Bracket::Service::BracketStructure;

my $schema = BracketTestSchema->init_schema(populate => 1);

# Use admin user (id=2) from test bootstrap.
my $player_id = 2;

my $valid_region = Bracket::Service::BracketValidator->validate_region_payload(
    $schema,
    $player_id,
    1,
    {
        p1 => 1,
        p2 => 3,
        p9 => 1,
    }
);
ok($valid_region->{ok}, 'valid region payload passes');

my $invalid_region = Bracket::Service::BracketValidator->validate_region_payload(
    $schema,
    $player_id,
    1,
    {
        p1 => 2,
        p2 => 3,
        p9 => 1,
    }
);
ok(!$invalid_region->{ok}, 'invalid region payload fails');
like(join(' ', @{$invalid_region->{errors}}), qr/not a valid advancement/, 'invalid region failure is continuity-related');

# Seed a full East path where UConn (team 15) advances deep, then ensure stale
# downstream picks are rejected when an earlier game changes to Furman (team 16).
for my $row (
    [7,  13],
    [8,  15],
    [11, 11],
    [12, 15],
    [13, 1],
    [14, 15],
    [15, 15],
) {
    $schema->resultset('Pick')->update_or_create({
        player => $player_id,
        game   => $row->[0],
        pick   => $row->[1],
    });
}

my $stale_downstream_region = Bracket::Service::BracketValidator->validate_region_payload(
    $schema,
    $player_id,
    1,
    {
        p8 => 16,
    }
);
ok(!$stale_downstream_region->{ok}, 'stale downstream inconsistency fails');
like(
    join(' ', @{$stale_downstream_region->{errors}}),
    qr/game 12/i,
    'stale downstream error points to affected descendant game'
);

my $coherent_region_update = Bracket::Service::BracketValidator->validate_region_payload(
    $schema,
    $player_id,
    1,
    {
        p8  => 16,
        p12 => 16,
        p14 => 16,
        p15 => 16,
    }
);
ok($coherent_region_update->{ok}, 'coherent region update passes');

# Seed region winners for final4 validation using graph-derived regional finals.
my $structure = Bracket::Service::BracketStructure->describe_bracket($schema);
my $region_winner_games = $structure->{region_winner_games_by_region};
my @semifinal_games = @{$structure->{semifinal_games}};
my $championship_game = $structure->{championship_game};

my %winner_by_region = (
    1 => 1,   # East
    2 => 17,  # South
    3 => 33,  # West
    4 => 49,  # Midwest
);
my %winner_by_game;
foreach my $region_id (keys %{$region_winner_games}) {
    my $game_id = $region_winner_games->{$region_id};
    my $team_id = $winner_by_region{$region_id};
    $winner_by_game{$game_id} = $team_id;
    $schema->resultset('Pick')->update_or_create({
        player => $player_id,
        game   => $game_id,
        pick   => $team_id,
    });
}

my %semifinal_winner_pick;
foreach my $semi (@semifinal_games) {
    my @parents = sort { $a <=> $b }
      map { $_->parent_game } $schema->resultset('GameGraph')->search({ game => $semi })->all;
    $semifinal_winner_pick{$semi} = $winner_by_game{$parents[0]};
}

my $first_semi = $semifinal_games[0];
my @first_semi_parents = sort { $a <=> $b }
  map { $_->parent_game } $schema->resultset('GameGraph')->search({ game => $first_semi })->all;
my $alternate_first_semi_winner = $winner_by_game{$first_semi_parents[1]};

my %valid_final4_payload = map { ('p' . $_ => $semifinal_winner_pick{$_}) } @semifinal_games;
$valid_final4_payload{'p' . $championship_game} = $semifinal_winner_pick{$first_semi};

my $valid_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    \%valid_final4_payload
);
ok($valid_final4->{ok}, 'valid final4 payload passes');

$schema->resultset('Pick')->update_or_create({
    player => $player_id,
    game   => $championship_game,
    pick   => $semifinal_winner_pick{$first_semi},
});
foreach my $semi (@semifinal_games) {
    $schema->resultset('Pick')->update_or_create({
        player => $player_id,
        game   => $semi,
        pick   => $semifinal_winner_pick{$semi},
    });
}

my $stale_downstream_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        ('p' . $first_semi => $alternate_first_semi_winner),
    }
);
ok(!$stale_downstream_final4->{ok}, 'stale downstream final4 inconsistency fails');
like(
    join(' ', @{$stale_downstream_final4->{errors}}),
    qr/game \Q$championship_game\E/i,
    'stale downstream final4 error points to affected descendant game'
);

my $coherent_final4_update = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        ('p' . $first_semi        => $alternate_first_semi_winner),
        ('p' . $championship_game => $alternate_first_semi_winner),
    }
);
ok($coherent_final4_update->{ok}, 'coherent final4 update passes');

my $invalid_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        ('p' . $first_semi => 64), # unrelated team id
    }
);
ok(!$invalid_final4->{ok}, 'invalid final4 payload fails');
like(join(' ', @{$invalid_final4->{errors}}), qr/not a valid advancement/, 'invalid final4 failure is continuity-related');

my $bad_param = Bracket::Service::BracketValidator->validate_region_payload(
    $schema,
    $player_id,
    1,
    {
        p1 => 'abc',
    }
);
ok(!$bad_param->{ok}, 'non-numeric team id is rejected');


done_testing();
