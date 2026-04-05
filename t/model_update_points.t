use strict;
use warnings;

use Test::More;

use lib qw(lib t/lib);
use BracketTestSchema;
use Bracket::Model::DBIC;

my $schema = BracketTestSchema->init_schema(populate => 1);

my $player = $schema->resultset('Player')->create({
    email      => 'portable-points@example.com',
    password   => 'secret',
    first_name => 'Portable',
    last_name  => 'Points',
});
my $zero_player = $schema->resultset('Player')->create({
    email      => 'portable-zero@example.com',
    password   => 'secret',
    first_name => 'Zero',
    last_name  => 'Points',
});

sub set_pick {
    my ($player_id, $game_id, $team_id) = @_;
    my ($pick) = $schema->resultset('Pick')->search({
        player => $player_id,
        game   => $game_id,
    });
    if ($pick) {
        $pick->update({ pick => $team_id });
        return;
    }
    $schema->resultset('Pick')->create({
        player => $player_id,
        game   => $game_id,
        pick   => $team_id,
    });
}

# Perfect bracket picks drive winner/lower-seed and round_out updates.
set_pick(1, 1, 2);  # 16 seed upset
set_pick(1, 2, 3);  # 8 seed
set_pick(1, 9, 2);  # winner from game 1 advances

# Player picks include one miss to ensure score aggregation behaves.
set_pick($player->id, 1, 2);
set_pick($player->id, 2, 4);
set_pick($player->id, 9, 2);
set_pick($zero_player->id, 1, 1);
set_pick($zero_player->id, 2, 4);
set_pick($zero_player->id, 9, 3);

my $stats = Bracket::Model::DBIC::_update_points_for_schema($schema);
like($stats, qr/total time:/, 'update_points reports execution stats');

my $game1 = $schema->resultset('Game')->find(1);
my $game2 = $schema->resultset('Game')->find(2);
my $game9 = $schema->resultset('Game')->find(9);

is($game1->get_column('winner'), undef, 'game 1 winner remains unchanged when current round is 2');
is($game1->get_column('lower_seed'), 0, 'game 1 lower_seed unchanged when current round is 2');
is($game2->get_column('winner'), undef, 'game 2 winner remains unchanged when current round is 2');
is($game2->get_column('lower_seed'), 0, 'game 2 lower_seed remains false for favorite');
is($game9->get_column('winner'), 2, 'game 9 winner updated from perfect bracket');
is($game9->get_column('lower_seed'), 1, 'game 9 lower_seed computed from parent winners');

is($schema->resultset('Team')->find(1)->get_column('round_out'), 7, 'first-round loser unchanged while current round is 2');
is($schema->resultset('Team')->find(4)->get_column('round_out'), 7, 'other first-round loser unchanged while current round is 2');
is($schema->resultset('Team')->find(3)->get_column('round_out'), 2, 'round-2 loser marked out in round 2');

my $region1_score = $schema->resultset('RegionScore')->find({
    player => $player->id,
    region => 1,
});
ok($region1_score, 'region score created for player');
is($region1_score->get_column('points'), 47, 'player receives expected region points from current-round state');

my $all_region_scores = $schema->resultset('RegionScore')->search({ player => $player->id })->count;
is($all_region_scores, 4, 'portable path maintains all region score rows per player');

my $player_row = $schema->resultset('Player')->find($player->id);
is($player_row->get_column('points'), 47, 'player total points updated from region scores');

my $zero_region_scores = $schema->resultset('RegionScore')->search({ player => $zero_player->id });
is($zero_region_scores->count, 4, 'player with no winning picks still has all region score rows');
is(
    $zero_region_scores->get_column('points')->sum,
    0,
    'player with no winning picks has zero total region points'
);
is(
    $schema->resultset('Player')->find($zero_player->id)->get_column('points'),
    0,
    'player total points zeroed when they have no correct picks'
);

done_testing();
