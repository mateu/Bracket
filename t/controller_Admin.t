use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Controller::Admin;
use Bracket::Service::BracketStructure;

{
    package TestUser;
    sub new { my ($class, $roles) = @_; return bless { roles => $roles || [] }, $class; }
    sub roles { return @{$_[0]->{roles}}; }
}

{
    package TestRequest;
    sub new { my ($class, $params) = @_; return bless { params => $params || {} }, $class; }
    sub params { return $_[0]->{params}; }
}

{
    package TestResponse;
    sub new { return bless { redirect_to => undef }, shift; }
    sub redirect { my ($self, $to) = @_; $self->{redirect_to} = $to; return; }
    sub redirect_to { return $_[0]->{redirect_to}; }
}

{
    package TestAction;
    sub new { my ($class, $name) = @_; return bless { name => $name }, $class; }
    sub name { return $_[0]->{name}; }
}

{
    package TestControllerRef;
    sub new { my ($class, $name) = @_; return bless { name => $name }, $class; }
    sub action_for { my ($self, $name) = @_; return TestAction->new($name); }
}

{
    package TestDBICModel;
    sub new { my ($class, $schema) = @_; return bless { schema => $schema, update_points_result => '<u>total time: 1.0</u><br>equity_cache: 0.5' }, $class; }
    sub schema { return $_[0]->{schema}; }
    sub update_points { return $_[0]->{update_points_result}; }
    sub count_player_picks {
        my ($self) = @_;
        my %counts;
        my $rs = $self->{schema}->resultset('Pick')->search(
            {},
            {
                select   => ['player', { count => 'game' }],
                as       => ['player', 'pick_count'],
                group_by => ['player'],
            }
        );
        while (my $row = $rs->next) {
            $counts{$row->get_column('player')} = $row->get_column('pick_count');
        }
        return \%counts;
    }

    sub count_region_picks {
        my ($self, $player_id) = @_;
        my %counts = (1 => 0, 2 => 0, 3 => 0, 4 => 0);
        my $rs = $self->{schema}->resultset('Pick')->search(
            {
                'me.player' => $player_id,
                'game.round' => { '<' => 5 },
            },
            {
                join     => [qw/pick game/],
                select   => ['pick.region', { count => 'me.game' }],
                as       => ['region_id', 'pick_count'],
                group_by => ['pick.region'],
            }
        );
        while (my $row = $rs->next) {
            $counts{$row->get_column('region_id')} = $row->get_column('pick_count');
        }
        return \%counts;
    }

    sub count_final4_picks {
        my ($self, $player_id) = @_;
        my $final4_ids = Bracket::Service::BracketStructure->final4_game_ids($self->{schema}) || [];
        return 0 if !@{$final4_ids};
        return $self->{schema}->resultset('Pick')->search({
            player => $player_id,
            game   => { -in => $final4_ids },
        })->count;
    }
}

{
    package TestContext;
    sub new {
        my ($class, $schema, $roles) = @_;
        return bless {
            stash => {},
            flash => {},
            go_to => undef,
            dbic  => TestDBICModel->new($schema),
            schema => $schema,
            user  => TestUser->new($roles),
            req   => TestRequest->new({}),
            response => TestResponse->new,
        }, $class;
    }

    sub stash { return $_[0]->{stash}; }

    sub model {
        my ($self, $name) = @_;
        return $self->{dbic} if $name eq 'DBIC';
        return $self->{schema}->resultset('Player') if $name eq 'DBIC::Player';
        die "unexpected model request: $name";
    }

    sub go {
        my ($self, $path) = @_;
        $self->{go_to} = $path;
    }

    sub go_to { return $_[0]->{go_to}; }
    sub user { return $_[0]->{user}; }
    sub req { return $_[0]->{req}; }
    sub request { return $_[0]->{req}; }
    sub response { return $_[0]->{response}; }
    sub flash { return $_[0]->{flash}; }
    sub controller { my ($self, $name) = @_; return TestControllerRef->new($name); }
    sub uri_for {
        my ($self, @parts) = @_;
        return join('/', map { ref($_) && $_->can('name') ? $_->name : $_ } @parts);
    }
}

my $schema = BracketTestSchema->init_schema(populate => 1);
my $controller = bless {}, 'Bracket::Controller::Admin';

my $non_admin = TestContext->new($schema, ['basic']);
is($controller->auto($non_admin), 0, 'non-admin is denied in auto');
is($non_admin->go_to, '/error_404', 'non-admin is redirected to 404');

my $admin = TestContext->new($schema, ['admin']);
$admin->stash->{is_admin} = 1;
is($controller->auto($admin), 1, 'admin passes auto gate');

$schema->resultset('Pick')->update_or_create({ player => 2, game => 7,  pick => 13 });
$schema->resultset('Pick')->update_or_create({ player => 2, game => 8,  pick => 15 });
$schema->resultset('Pick')->update_or_create({ player => 2, game => 12, pick => 1  });

$controller->continuity_audit($admin);
is($admin->stash->{template}, 'admin/continuity_audit.tt', 'audit action sets template');
ok(ref $admin->stash->{continuity_issues} eq 'ARRAY', 'audit action stashes issue list');
ok(scalar @{$admin->stash->{continuity_issues}} >= 1, 'audit action exposes continuity issues');

my $player3 = $schema->resultset('Player')->create({
    email      => 'player3@test.com',
    password   => 'test',
    first_name => 'Full',
    last_name  => 'Bracket',
    active     => 1,
});
my $player3_id = $player3->id;

$schema->resultset('Player')->search({ id => { -in => [2, $player3_id] } })->update({ active => 1 });
$schema->resultset('Pick')->search({ player => { -in => [2, $player3_id] } })->delete;
for my $game_id (1 .. 10) {
    $schema->resultset('Pick')->create({
        player => 2,
        game   => $game_id,
        pick   => 1,
    });
}
for my $game_id (1 .. 63) {
    $schema->resultset('Pick')->create({
        player => $player3_id,
        game   => $game_id,
        pick   => 1,
    });
}

$controller->incomplete_submissions($admin);
is($admin->stash->{template}, 'admin/incomplete_submissions.tt', 'incomplete submissions action sets template');
is($admin->stash->{expected_total_picks}, 63, 'incomplete submissions uses structure-derived total picks');
is($admin->stash->{expected_final4_picks}, 3, 'incomplete submissions uses structure-derived final4 picks');
is_deeply($admin->stash->{region_ids}, [1,2,3,4], 'incomplete submissions stashes dynamic region id list');

my $report_rows = $admin->stash->{incomplete_submissions};
ok(ref $report_rows eq 'ARRAY', 'incomplete submissions are stashed as an array');
is(scalar @{$report_rows}, 1, 'only incomplete active players are included');

is($report_rows->[0]->{player_id}, 2, 'incomplete player id is reported');
is($report_rows->[0]->{total_picks}, 10, 'total picks count is reported');
is($report_rows->[0]->{missing_total}, 53, 'missing pick count is reported');
is($report_rows->[0]->{final4_picks}, 0, 'final4 picks count is reported');

# update_points surfaces timing stats and redirects back to leaderboard
$controller->update_points($admin);
like($admin->flash->{status_msg}, qr/equity_cache:/, 'update_points flash includes equity cache timing');
is($admin->response->redirect_to, 'all', 'update_points redirects to leaderboard');

# equity_report reuses cached default projection only for default cache params
my $cached_projection = {
    player_projections => [
        { player_id => 2, projected_first_pct => '12.34', projected_podium_pct => '56.78', max_possible_points => 123, projected_score_avg => '88.88' },
    ],
    source => 'cache',
};
my $live_projection = {
    player_projections => [
        { player_id => 2, projected_first_pct => '98.76', projected_podium_pct => '54.32', max_possible_points => 321, projected_score_avg => '77.77' },
    ],
    source => 'live',
};
my ($cache_calls, $project_calls) = (0, 0);

{
    no warnings 'redefine';
    local *Bracket::Service::EquityProjection::load_default_cache = sub {
        my ($class, $schema_arg) = @_;
        $cache_calls++;
        return $cached_projection;
    };
    local *Bracket::Service::EquityProjection::project = sub {
        my ($class, $schema_arg, $opts) = @_;
        $project_calls++;
        return $live_projection;
    };

    $admin->{req} = TestRequest->new({ iterations => 2000, seed => 17 });
    $controller->equity_report($admin);
    is($admin->stash->{projection}, $cached_projection, 'equity_report uses cached projection for leaderboard-default params');
    is($cache_calls, 1, 'cached projection loader called once for default-cache params');
    is($project_calls, 0, 'live projection skipped when default cache is available');

    $admin->{req} = TestRequest->new({ iterations => 4000, seed => 17 });
    $controller->equity_report($admin);
    is($admin->stash->{projection}, $live_projection, 'equity_report keeps live projection for non-cached params');
    is($project_calls, 1, 'live projection called for non-cached params');
}

done_testing();
