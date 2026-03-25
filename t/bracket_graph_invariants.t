use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::BracketValidator;

{
    my $schema = BracketTestSchema->init_schema(populate => 1);
    my $result = Bracket::Service::BracketValidator->validate_graph_invariants($schema);
    ok($result->{ok}, 'default bracket graph satisfies invariants');
}

{
    my $schema = BracketTestSchema->init_schema(populate => 1);
    $schema->resultset('GameGraph')->search({
        game        => 9,
        parent_game => 1,
    })->delete;

    my $result = Bracket::Service::BracketValidator->validate_graph_invariants($schema);
    ok(!$result->{ok}, 'missing parent edge is detected');
    like(
        join(' ', @{$result->{errors} || []}),
        qr/game 9 .* exactly 2 parent games/i,
        'error reports incorrect parent count'
    );
}

{
    my $schema = BracketTestSchema->init_schema(populate => 1);
    $schema->resultset('GameTeamGraph')->create({
        game => 9,
        team => 1,
    });

    my $result = Bracket::Service::BracketValidator->validate_graph_invariants($schema);
    ok(!$result->{ok}, 'fixed team on later-round game is detected');
    like(
        join(' ', @{$result->{errors} || []}),
        qr/game 9 .* should not have fixed teams/i,
        'error reports invalid fixed-team mapping'
    );
}

done_testing();
