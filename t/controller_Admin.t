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
}

{
    package TestContext;
    sub new {
        my ($class, $schema, $roles) = @_;
        return bless {
            stash => {},
            go_to => undef,
            dbic  => TestDBICModel->new($schema),
            user  => TestUser->new($roles),
        }, $class;
    }

    sub stash { return $_[0]->{stash}; }

    sub model {
        my ($self, $name) = @_;
        return $self->{dbic} if $name eq 'DBIC';
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

done_testing();
