use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::EquityProjection;
use Bracket::Model::DBIC;

my $schema = BracketTestSchema->init_schema(populate => 1);

# ── Arrange: two active pool players with picks ───────────────────────────────

$schema->resultset('Player')->search({ id => { '!=' => 1 } })->update({ active => 0 });

my $player_a = $schema->resultset('Player')->create({
    username   => 'cache_tester_a',
    password   => 'test',
    first_name => 'Cache',
    last_name  => 'Alpha',
    email      => 'cache_a@example.test',
    active     => 1,
    points     => 0,
});
my $player_b = $schema->resultset('Player')->create({
    username   => 'cache_tester_b',
    password   => 'test',
    first_name => 'Cache',
    last_name  => 'Beta',
    email      => 'cache_b@example.test',
    active     => 1,
    points     => 0,
});

# Give both players picks on a couple of games
$schema->resultset('Pick')->delete;
for my $row (
    [$player_a->id, 1, 1],
    [$player_a->id, 2, 3],
    [$player_b->id, 1, 1],
    [$player_b->id, 2, 4],
) {
    $schema->resultset('Pick')->create({ player => $row->[0], game => $row->[1], pick => $row->[2] });
}

# ── Test 1: fresh schema has no cached projection ─────────────────────────────

my $empty = Bracket::Service::EquityProjection->load_default_cache($schema);
is($empty, undef, 'load_default_cache returns undef when equity_cache is empty');

# ── Test 2: refresh_default_cache populates the cache ─────────────────────────

Bracket::Service::EquityProjection->refresh_default_cache($schema);

my $cache = Bracket::Service::EquityProjection->load_default_cache($schema);
ok(defined $cache, 'load_default_cache returns data after refresh_default_cache');
ok(ref($cache) eq 'HASH', 'cached result is a hash');
ok(exists $cache->{player_projections}, 'cached result has player_projections key');

my @projections = @{ $cache->{player_projections} || [] };
ok(@projections >= 2, 'cache contains at least two player projection rows');

my %by_player = map { $_->{player_id} => $_ } @projections;
ok(exists $by_player{$player_a->id}, 'player A has a cached projection row');
ok(exists $by_player{$player_b->id}, 'player B has a cached projection row');

my $row_a = $by_player{$player_a->id};
like($row_a->{projected_first_pct},  qr/^\d+\.\d+$/, 'projected_first_pct looks numeric');
like($row_a->{projected_podium_pct}, qr/^\d+\.\d+$/, 'projected_podium_pct looks numeric');
like($row_a->{projected_score_avg},  qr/^\d+\.\d+$/, 'projected_score_avg looks numeric');
ok(defined $row_a->{max_possible_points}, 'max_possible_points is present');

# ── Test 3: refresh overwrites stale cache ─────────────────────────────────────

# Manually insert a sentinel row, then refresh and verify it's gone
$schema->resultset('EquityCache')->update_or_create({
    player_id            => $player_a->id,
    cache_key            => 'default',
    current_points       => 9999,
    max_possible_points  => 9999,
    projected_first_pct  => '99.00',
    projected_podium_pct => '99.00',
    projected_score_avg  => '999.00',
});

Bracket::Service::EquityProjection->refresh_default_cache($schema);

my $after = Bracket::Service::EquityProjection->load_default_cache($schema);
my %after_by_player = map { $_->{player_id} => $_ } @{ $after->{player_projections} || [] };
isnt($after_by_player{$player_a->id}{current_points}, 9999,
    'refresh_default_cache replaces stale cache rows');

# ── Test 4: _update_points_for_schema also refreshes the cache ───────────────

$schema->resultset('EquityCache')->delete;
is(Bracket::Service::EquityProjection->load_default_cache($schema), undef,
    'cache is empty before update_points');

# Give perfect-bracket player a pick so update_points has something to do
$schema->resultset('Pick')->search({ player => 1 })->delete;
$schema->resultset('Pick')->create({ player => 1, game => 9, pick => 1 });

Bracket::Model::DBIC::_update_points_for_schema($schema);

my $after_update = Bracket::Service::EquityProjection->load_default_cache($schema);
ok(defined $after_update, '_update_points_for_schema refreshes the equity cache');
ok(exists $after_update->{player_projections}, 'cache populated by update_points has player_projections');

# ── Test 5: MySQL update_points path also refreshes the cache ─────────────────

{
    package Local::TestDBH;
    sub new { bless { Driver => { Name => 'mysql' } }, shift }

    package Local::TestStorage;
    sub new { bless { dbh => Local::TestDBH->new }, shift }
    sub dbh { shift->{dbh} }

    package Local::TestSchema;
    sub new { bless { storage => Local::TestStorage->new }, shift }
    sub storage { shift->{storage} }
}

my $fake_schema = Local::TestSchema->new;
my $mysql_path_called = 0;
my $cache_refresh_called = 0;
my $cache_refresh_schema;

{
    no warnings 'redefine';
    local *Bracket::Model::DBIC::_update_points_mysql = sub {
        my ($schema_arg) = @_;
        $mysql_path_called++;
        return 'mysql stats';
    };
    local *Bracket::Service::EquityProjection::refresh_default_cache = sub {
        my ($class, $schema_arg) = @_;
        $cache_refresh_called++;
        $cache_refresh_schema = $schema_arg;
        return;
    };

    my $stats = Bracket::Model::DBIC::_update_points_for_schema($fake_schema);
    is($stats, 'mysql stats', 'mysql path returns raw update_points stats');
}

is($mysql_path_called, 1, 'mysql update_points path invoked exactly once');
is($cache_refresh_called, 1, 'mysql update_points path refreshes equity cache');
is($cache_refresh_schema, $fake_schema, 'mysql cache refresh receives same schema object');

done_testing();
