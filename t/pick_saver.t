use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::PickSaver;

my $schema = BracketTestSchema->init_schema(populate => 1);
my $player_id = 2; # admin user from test seed data

my $insert_result = Bracket::Service::PickSaver->persist_pick_map(
    $schema,
    $player_id,
    {
        1 => 1,
        2 => 3,
    },
);
ok($insert_result->{ok}, 'insert path succeeds');

my ($game1_pick) = $schema->resultset('Pick')->search({ player => $player_id, game => 1 });
my ($game2_pick) = $schema->resultset('Pick')->search({ player => $player_id, game => 2 });
is($game1_pick->pick->id, 1, 'game 1 pick inserted');
is($game2_pick->pick->id, 3, 'game 2 pick inserted');

my $update_result = Bracket::Service::PickSaver->persist_pick_map(
    $schema,
    $player_id,
    {
        1 => 2,
    },
);
ok($update_result->{ok}, 'update path succeeds');

my @game1_rows = $schema->resultset('Pick')->search({ player => $player_id, game => 1 });
is(scalar @game1_rows, 1, 'update path does not create duplicate rows');
is($game1_rows[0]->pick->id, 2, 'game 1 pick updated in place');

my $missing_schema = Bracket::Service::PickSaver->persist_pick_map(
    undef,
    $player_id,
    { 1 => 1 },
);
ok(!$missing_schema->{ok}, 'missing schema is rejected');

my $bad_player = Bracket::Service::PickSaver->persist_pick_map(
    $schema,
    0,
    { 1 => 1 },
);
ok(!$bad_player->{ok}, 'invalid player id is rejected');

done_testing();
