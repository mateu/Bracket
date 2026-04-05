use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::BracketStructure;

my $schema = BracketTestSchema->init_schema(populate => 1);

my $structure = Bracket::Service::BracketStructure->describe_bracket($schema);

is($structure->{championship_game_id}, 63, 'championship game is derived from graph roots');
is_deeply($structure->{semifinal_game_ids}, [61, 62], 'semifinals are derived from championship parents');
is_deeply($structure->{final4_game_ids}, [61, 62, 63], 'final4 games are derived from graph topology');
is_deeply(
    $structure->{region_winner_games_by_region},
    {
        1 => 15,
        2 => 30,
        3 => 45,
        4 => 60,
    },
    'region-winner games are derived from graph topology',
);
is($structure->{round_for_game}->{63}, 6, 'round map includes championship round');

my $region_winner_games = Bracket::Service::BracketStructure->region_winner_games_by_region($schema);
is_deeply($region_winner_games, $structure->{region_winner_games_by_region}, 'region helper matches described structure');

my $final4_games = Bracket::Service::BracketStructure->final4_game_ids($schema);
is_deeply($final4_games, $structure->{final4_game_ids}, 'final4 helper matches described structure');

my $pick_targets = Bracket::Service::BracketStructure->pick_targets($schema);
is($pick_targets->{total_picks}, 63, 'pick targets derive total expected picks from game topology');
is($pick_targets->{final4_picks}, 3, 'pick targets derive expected final4 picks from graph topology');
is_deeply(
    $pick_targets->{region_picks_by_region},
    {
        1 => 15,
        2 => 15,
        3 => 15,
        4 => 15,
    },
    'pick targets derive expected region pick counts from topology',
);

done_testing();
