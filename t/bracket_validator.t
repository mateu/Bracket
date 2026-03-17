use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::BracketValidator;

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

# Seed region winners for final4 validation.
for my $row (
    [15, 1],   # East winner
    [30, 17],  # South winner
    [45, 33],  # West winner
    [60, 49],  # Midwest winner
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
        p61 => 1,
        p62 => 33,
        p63 => 1,
    }
);
ok($valid_final4->{ok}, 'valid final4 payload passes');

my $invalid_final4 = Bracket::Service::BracketValidator->validate_final4_payload(
    $schema,
    $player_id,
    {
        p61 => 49, # not from game 15 or 30 winners
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
