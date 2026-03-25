use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::BracketStructure;

my $schema = BracketTestSchema->init_schema(populate => 1);

my $structure = Bracket::Service::BracketStructure->describe_bracket($schema);

is($structure->{championship_game}, 63, 'championship game is derived from graph roots');
is_deeply($structure->{semifinal_games}, [61, 62], 'semifinals are derived from championship parents');
is_deeply($structure->{final4_games}, [61, 62, 63], 'final4 game ids include semis and championship');
is_deeply(
    $structure->{region_winner_games_by_region},
    { 1 => 15, 2 => 30, 3 => 45, 4 => 60 },
    'regional winner games map is derived by region from graph ancestry'
);

done_testing();
