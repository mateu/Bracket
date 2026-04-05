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

my $structure = Bracket::Service::BracketStructure->describe_bracket($schema);
ok(keys %{ $structure->{region_winner_games_by_region} } == 4, 'derived region-winner games cover all regions');
my $region_winner_games = $structure->{region_winner_games_by_region};
my $final4_games = $structure->{final4_game_ids};
ok(@{$final4_games} == 3, 'derived final4 game structure has exactly 3 games');

my $championship_game = $structure->{championship_game_id};
my @semifinal_games   = sort { $a <=> $b } @{ $structure->{semifinal_game_ids} };

# Seed region winners for final4 validation.
for my $row (
    [$region_winner_games->{1}, 1],   # East winner
    [$region_winner_games->{2}, 17],  # South winner
    [$region_winner_games->{3}, 33],  # West winner
    [$region_winner_games->{4}, 49],  # Midwest winner
) {
    $schema->resultset('Pick')->update_or_create({
        player => $player_id,
        game   => $row->[0],
        pick   => $row->[1],
    });
}

my $valid_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        ('p' . $semifinal_games[0]) => 1,
        ('p' . $semifinal_games[1]) => 33,
        ('p' . $championship_game) => 1,
    }
);
ok($valid_final4->{ok}, 'valid final4 payload passes');

$schema->resultset('Pick')->update_or_create({
    player => $player_id,
    game   => $semifinal_games[0],
    pick   => 1,
});
$schema->resultset('Pick')->update_or_create({
    player => $player_id,
    game   => $semifinal_games[1],
    pick   => 33,
});
$schema->resultset('Pick')->update_or_create({
    player => $player_id,
    game   => $championship_game,
    pick   => 1,
});

my $stale_downstream_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        ('p' . $semifinal_games[0]) => 17,
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
        ('p' . $semifinal_games[0]) => 17,
        ('p' . $championship_game) => 17,
    }
);
ok($coherent_final4_update->{ok}, 'coherent final4 update passes');

my $invalid_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        ('p' . $semifinal_games[0]) => 49, # not from the two semifinal feeder winners
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

{
    no warnings 'redefine';
    local *Bracket::Service::BracketStructure::region_winner_games_by_region = sub {
        return { 1 => 30 };
    };

    my $derived_region_games = Bracket::Service::BracketValidator::_region_game_ids_for_region($schema, 1);
    ok($derived_region_games->{30}, 'region game scope includes remapped region-winner game');
    ok($derived_region_games->{16}, 'region game scope follows remapped ancestry');
    ok(!$derived_region_games->{1}, 'region game scope excludes original range when topology remaps');

    my $remapped_region_validation = Bracket::Service::BracketValidator->validate_region_payload(
        $schema,
        $player_id,
        1,
        {
            p30 => 1,
        }
    );
    ok(!$remapped_region_validation->{ok}, 'remapped validation still enforces pick correctness');
    unlike(
        join(' ', @{$remapped_region_validation->{errors}}),
        qr/outside region 1/i,
        'remapped topology is used instead of fixed 1..15 range'
    );
}


done_testing();
