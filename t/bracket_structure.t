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

my $targets = Bracket::Service::BracketStructure->submission_targets($schema);
is($targets->{expected_total_picks}, 63, 'submission targets expose total expected picks');
is($targets->{expected_final4_picks}, 3, 'submission targets expose final4 expected picks');
is_deeply(
    $targets->{region_ids},
    [1, 2, 3, 4],
    'submission targets expose normalized region ids',
);
is_deeply(
    $targets->{expected_region_picks_by_region},
    {
        1 => 15,
        2 => 15,
        3 => 15,
        4 => 15,
    },
    'submission targets expose per-region expected picks',
);

{
    no warnings 'redefine';
    local *Bracket::Service::BracketStructure::pick_targets = sub {
        return {
            total_picks            => 0,
            final4_picks           => 'x',
            region_picks_by_region => {
                2 => 0,
                5 => 7,
            },
        };
    };

    my $fallback = Bracket::Service::BracketStructure->submission_targets(
        undef,
        [2, 5, 9]
    );
    is($fallback->{expected_total_picks}, 63, 'submission targets fallback total to 63');
    is($fallback->{expected_final4_picks}, 3, 'submission targets fallback final4 to 3');
    is_deeply($fallback->{region_ids}, [2, 5, 9], 'submission targets preserve provided region ids');
    is_deeply(
        $fallback->{expected_region_picks_by_region},
        {
            2 => 15,
            5 => 7,
            9 => 15,
        },
        'submission targets fallback per-region expected picks to 15',
    );
}

done_testing();
