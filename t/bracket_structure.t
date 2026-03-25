use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::BracketStructure;

my $schema = BracketTestSchema->init_schema(populate => 1);

my $region_winner_games = Bracket::Service::BracketStructure->region_winner_games_by_region($schema);
is_deeply(
    $region_winner_games,
    {
        1 => 15,
        2 => 30,
        3 => 45,
        4 => 60,
    },
    'region-winner games are derived from graph topology',
);

my $final4_games = Bracket::Service::BracketStructure->final4_game_ids($schema);
is_deeply(
    $final4_games,
    [61, 62, 63],
    'final4 games are derived from graph topology',
);

done_testing();
