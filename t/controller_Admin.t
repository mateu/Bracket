use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Controller::Admin;

{
    package TestUser;
    sub new { my ($class, $roles) = @_; return bless { roles => $roles || [] }, $class; }
    sub roles { return @{$_[0]->{roles}}; }
}

{
    package TestDBICModel;
    sub new { my ($class, $schema) = @_; return bless { schema => $schema }, $class; }
    sub schema { return $_[0]->{schema}; }
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
        return $self->{schema}->resultset('Pick')->search({
            player => $player_id,
            game   => { '>' => 60 },
        })->count;
    }
}

{
    package TestContext;
    sub new {
        my ($class, $schema, $roles) = @_;
        return bless {
            stash => {},
            go_to => undef,
            dbic  => TestDBICModel->new($schema),
            schema => $schema,
            user  => TestUser->new($roles),
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

my $report_rows = $admin->stash->{incomplete_submissions};
ok(ref $report_rows eq 'ARRAY', 'incomplete submissions are stashed as an array');
is(scalar @{$report_rows}, 1, 'only incomplete active players are included');

is($report_rows->[0]->{player_id}, 2, 'incomplete player id is reported');
is($report_rows->[0]->{total_picks}, 10, 'total picks count is reported');
is($report_rows->[0]->{missing_total}, 53, 'missing pick count is reported');
is($report_rows->[0]->{final4_picks}, 0, 'final4 picks count is reported');

done_testing();
