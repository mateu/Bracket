use strict;
use warnings;

use Test::More;

use lib qw(lib t/lib);
use BracketTestSchema;
use Bracket::Model::DBIC;

{
    package TestDBICModel;
    sub new { my ($class, $schema) = @_; return bless { schema => $schema }, $class; }
    sub schema { return $_[0]->{schema}; }
}

my $schema = BracketTestSchema->init_schema(populate => 1);

$schema->resultset('Region')->create({
    id   => 5,
    name => 'Wildcard',
});
$schema->resultset('Team')->create({
    id       => 500,
    seed     => 1,
    name     => 'Wildcard Team',
    region   => 5,
    round_out => 7,
});
$schema->resultset('Game')->create({
    id         => 500,
    winner     => undef,
    round      => 1,
    lower_seed => 0,
});

my $player = $schema->resultset('Player')->create({
    email      => 'dynamic-region-counts@example.com',
    password   => 'secret',
    first_name => 'Dynamic',
    last_name  => 'Region',
});

$schema->resultset('Pick')->create({
    player => $player->id,
    game   => 500,
    pick   => 500,
});

my $model = TestDBICModel->new($schema);
my $counts = Bracket::Model::DBIC::count_region_picks($model, $player->id);

ok(exists $counts->{5}, 'count map includes dynamically added region');
is($counts->{5}, 1, 'count map includes picks from dynamically added region');

for my $region_id (1 .. 4) {
    is($counts->{$region_id}, 0, "existing region $region_id defaults to zero when no picks exist");
}

done_testing();
