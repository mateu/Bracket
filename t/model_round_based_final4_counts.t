use strict;
use warnings;

use Test::More;

use lib qw(lib t/lib);
use BracketTestSchema;
use Bracket::Model::DBIC;

{
    package Local::Model;
    sub new {
        my ($class, $schema) = @_;
        return bless { schema => $schema }, $class;
    }
    sub schema { return $_[0]->{schema}; }
}

plan skip_all => 'SQLite-specific test requires sqlite_create_function'
    unless BracketTestSchema->get_schema->storage->dbh->can('sqlite_create_function');

my $schema = BracketTestSchema->init_schema(populate => 1);
my $model  = Local::Model->new($schema);

my $dbh = $schema->storage->dbh;

# SQLite test DB does not define these UDFs by default; register test-safe stubs.
$dbh->sqlite_create_function('get_loser', 1, sub { return -1; });
$dbh->sqlite_create_function('get_first_round_loser', 1, sub { return -1; });

my $player = $schema->resultset('Player')->create({
    email      => 'round-based-final4@example.com',
    password   => 'secret',
    first_name => 'Round',
    last_name  => 'Based',
});

# Simulate bracket topology drift where a semifinal game is not > 60.
$schema->resultset('Game')->find(60)->update({ round => 5 });
$schema->resultset('Pick')->create({
    player => $player->id,
    game   => 60,
    pick   => 1,
});

is(
    Bracket::Model::DBIC::count_final4_picks($model, $player->id),
    1,
    'count_final4_picks follows game round instead of fixed game id threshold',
);

# Add one known-correct pick in a game flagged as upset to validate
# combined accuracy metric aggregation.
my $accuracy_game_id = 9100;
my $accuracy_team_id = 9100;
$schema->resultset('Game')->create({
    id         => $accuracy_game_id,
    round      => 2,
    lower_seed => 1,
});
$schema->resultset('Team')->create({
    id        => $accuracy_team_id,
    seed      => 9,
    name      => 'Accuracy Team',
    region    => 1,
    round_out => 7,
});
$schema->resultset('Pick')->create({
    player => 1,
    game   => $accuracy_game_id,
    pick   => $accuracy_team_id,
});
$schema->resultset('Pick')->create({
    player => $player->id,
    game   => $accuracy_game_id,
    pick   => $accuracy_team_id,
});

my $round4_game_id = 9001;
my $round4_team_id = 9001;

$schema->resultset('Game')->create({
    id    => $round4_game_id,
    round => 4,
});
$schema->resultset('Team')->create({
    id       => $round4_team_id,
    seed     => 1,
    name     => 'RoundBased Team',
    region   => 1,
    round_out => 7,
});

# Create a player with id 24 to satisfy foreign key constraints on Pick.
$schema->resultset('Player')->create({
    id         => 24,
    email      => 'player-24@example.com',
    password   => 'secret',
    first_name => 'Player',
    last_name  => 'TwentyFour',
});

# player 24 drives games_remaining in count_player_final4_teams_left.
$schema->resultset('Pick')->create({
    player => 24,
    game   => $round4_game_id,
    pick   => $round4_team_id,
});
$schema->resultset('Pick')->create({
    player => $player->id,
    game   => $round4_game_id,
    pick   => $round4_team_id,
});

my ($teams_left, $max_left) = Bracket::Model::DBIC::count_player_final4_teams_left($model);
is(
    ($teams_left->{$player->id} || 0) >= 1,
    1,
    'count_player_final4_teams_left includes round-based final4-path games outside fixed ids',
);
ok(
    defined $max_left && $max_left >= 1,
    'count_player_final4_teams_left reports max_left from computed map',
);

my ($correct_by_player, $max_correct, $upset_by_player, $max_upsets)
    = Bracket::Model::DBIC::count_player_pick_accuracy_metrics($model);
is(
    ($correct_by_player->{$player->id} || 0) >= 1,
    1,
    'count_player_pick_accuracy_metrics reports correct picks from shared query',
);
is(
    ($upset_by_player->{$player->id} || 0) >= 1,
    1,
    'count_player_pick_accuracy_metrics reports upset picks from shared query',
);
ok(defined $max_correct && $max_correct >= 1, 'count_player_pick_accuracy_metrics returns max_correct');
ok(defined $max_upsets && $max_upsets >= 1, 'count_player_pick_accuracy_metrics returns max_upsets');

my ($combined_teams_left, $combined_max_left, $combined_fi4_left, $combined_max_fi4_left)
    = Bracket::Model::DBIC::count_player_remaining_team_metrics($model);
is(
    ($combined_teams_left->{$player->id} || 0) >= 1,
    1,
    'count_player_remaining_team_metrics reports teams_left from shared query',
);
is(
    ($combined_fi4_left->{$player->id} || 0) >= 1,
    1,
    'count_player_remaining_team_metrics reports final4 teams left from shared query',
);
ok(defined $combined_max_left && $combined_max_left >= 1, 'count_player_remaining_team_metrics returns max_left');
ok(defined $combined_max_fi4_left && $combined_max_fi4_left >= 1, 'count_player_remaining_team_metrics returns max_final4_left');

done_testing();
