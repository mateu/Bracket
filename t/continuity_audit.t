use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::ContinuityAudit;

my $schema = BracketTestSchema->init_schema(populate => 1);
my $player_id = 2;

for my $row (
    [7, 13],
    [8, 15],
    [12, 15],
) {
    $schema->resultset('Pick')->update_or_create({
        player => $player_id,
        game   => $row->[0],
        pick   => $row->[1],
    });
}

my $healthy = Bracket::Service::ContinuityAudit->issues_for_schema($schema);
is(scalar @{$healthy}, 0, 'healthy picks report no continuity issues');

$schema->resultset('Pick')->search({
    player => $player_id,
    game   => 12,
})->update({
    pick => 1,
});

my $issues = Bracket::Service::ContinuityAudit->issues_for_schema($schema);
ok(@{$issues} >= 1, 'invalid downstream pick is reported');

my ($target) = grep {
    $_->{player_id} == $player_id
      && $_->{game_id} == 12
      && $_->{invalid_pick_id} == 1
} @{$issues};

ok($target, 'issue includes player/game/invalid pick details');
is_deeply(
    [ sort { $a <=> $b } @{$target->{allowed_pick_ids}} ],
    [ 13, 15 ],
    'issue includes allowed parent-derived picks'
);

done_testing();
