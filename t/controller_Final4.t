use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Controller::Final4;
use Bracket::Service::BracketStructure;

{
    package TestUser;
    sub new { my ($class, $args) = @_; return bless { id => $args->{id}, roles => $args->{roles} || [] }, $class; }
    sub id { return $_[0]->{id}; }
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
        my ($class, $schema, $user) = @_;
        return bless {
            stash    => {},
            flash    => {},
            schema   => $schema,
            dbic     => TestDBICModel->new($schema),
            user_obj => $user,
            go_to    => undef,
        }, $class;
    }
    sub stash { return $_[0]->{stash}; }
    sub flash { return $_[0]->{flash}; }
    sub go { $_[0]->{go_to} = $_[1]; return; }
    sub user { return $_[0]->{user_obj}; }
    sub model {
        my ($self, $name) = @_;
        return $self->{dbic} if $name eq 'DBIC';
        return $self->{schema}->resultset('Player') if $name eq 'DBIC::Player';
        return $self->{schema}->resultset('Pick') if $name eq 'DBIC::Pick';
        return $self->{schema}->resultset('Region') if $name eq 'DBIC::Region';
        die "unexpected model request: $name";
    }
}

my $schema = BracketTestSchema->init_schema(populate => 1);
my $controller = bless {}, 'Bracket::Controller::Final4';
my $player_id = 2;

my $team_for_game1 = $schema->resultset('GameTeamGraph')->search(
    { game => 1 },
    { order_by => 'team', rows => 1 }
)->first->team;
my @game2_teams = map { $_->team } $schema->resultset('GameTeamGraph')->search(
    { game => 2 },
    { order_by => 'team' }
)->all;
ok(@game2_teams >= 2, 'game 2 has at least two teams available for in/out status setup');

$schema->resultset('Pick')->update_or_create({ player => 1, game => 1, pick => $team_for_game1 });
$schema->resultset('Pick')->update_or_create({ player => $player_id, game => 1, pick => $team_for_game1 });
$schema->resultset('Pick')->update_or_create({ player => 1, game => 2, pick => $game2_teams[0] });
$schema->resultset('Pick')->update_or_create({ player => $player_id, game => 2, pick => $game2_teams[1] });

my $structure = Bracket::Service::BracketStructure->describe_bracket($schema);
my $context_for_make = TestContext->new($schema, TestUser->new({ id => $player_id, roles => ['basic'] }));
$controller->make($context_for_make, $player_id);

is($context_for_make->stash->{template}, 'final4/make_final4_picks.tt', 'make sets final4 make template');
is($context_for_make->stash->{final_4_javascript}, 1, 'make enables final4 javascript');
is($context_for_make->stash->{class_for}{1}, 'in', 'make marks matching winning pick as in');
is($context_for_make->stash->{class_for}{2}, 'out', 'make marks non-matching winning pick as out');
is_deeply(
    $context_for_make->stash->{region_winner_game_id_for},
    $structure->{region_winner_games_by_region},
    'make stashes region winner game map from structure service',
);

my $context_for_view = TestContext->new($schema, TestUser->new({ id => $player_id, roles => ['basic'] }));
$controller->view($context_for_view, $player_id);

is($context_for_view->stash->{template}, 'final4/view_final4_picks.tt', 'view sets final4 view template');
is($context_for_view->stash->{no_javascript}, 1, 'view disables javascript');
ok($context_for_view->stash->{regions}, 'view stashes region resultset');
is_deeply(
    $context_for_view->stash->{class_for},
    $context_for_make->stash->{class_for},
    'view and make compute identical class status map',
);
is_deeply(
    $context_for_view->stash->{picks},
    $context_for_make->stash->{picks},
    'view and make stash identical pick map',
);
is_deeply(
    $context_for_view->stash->{game_routes},
    $context_for_make->stash->{game_routes},
    'view and make share same derived game routes',
);

done_testing();
