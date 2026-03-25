use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::PickStatus;

my $schema = BracketTestSchema->init_schema(populate => 1);

# Admin user from fixture bootstrap.
my $player_id = 2;

$schema->resultset('Pick')->update_or_create({ player => $player_id, game => 1, pick => 1 });
$schema->resultset('Pick')->update_or_create({ player => $player_id, game => 2, pick => 3 });
$schema->resultset('Pick')->update_or_create({ player => $player_id, game => 9, pick => 1 });

# Perfect picks establish explicit winners for game 1 and 2.
$schema->resultset('Pick')->update_or_create({ player => 1, game => 1, pick => 1 });
$schema->resultset('Pick')->update_or_create({ player => 1, game => 2, pick => 4 });

my $player_picks = Bracket::Service::PickStatus->player_picks($schema, $player_id);
is(scalar @{$player_picks}, 3, 'loads player picks');

my $pick_map = Bracket::Service::PickStatus->pick_map_from_rows($player_picks);
is($pick_map->{1}->id, 1, 'pick_map contains game 1 team');
is($pick_map->{2}->id, 3, 'pick_map contains game 2 team');

my $class_for = Bracket::Service::PickStatus->classify_pick_rows($schema, $player_picks);
is($class_for->{1}, 'in', 'matching perfect pick is classified in');
is($class_for->{2}, 'out', 'mismatched perfect pick is classified out');
is($class_for->{9}, 'pending', 'no winner + still alive team is classified pending');

# Without a perfect winner for game 9, status should flip to out once team is marked out.
$schema->resultset('Team')->find(1)->update({ round_out => 2 });
$player_picks = Bracket::Service::PickStatus->player_picks($schema, $player_id);
$class_for = Bracket::Service::PickStatus->classify_pick_rows($schema, $player_picks);
is($class_for->{9}, 'out', 'no winner + eliminated team is classified out');

my $winning_pick_ids = Bracket::Service::PickStatus->winning_pick_ids($schema);
is($winning_pick_ids->{1}, 1, 'winning_pick_ids includes perfect winner for game 1');
is($winning_pick_ids->{2}, 4, 'winning_pick_ids includes perfect winner for game 2');
ok(!exists $winning_pick_ids->{9}, 'winning_pick_ids omits games with no winner');

done_testing();
