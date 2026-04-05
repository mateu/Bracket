use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Bracket::Controller::Player' }

{
    package t::FakePlayer;

    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }

    sub id         { shift->{id} }
    sub first_name { shift->{first_name} }
    sub last_name  { shift->{last_name} }
    sub points     { shift->{points} }
}

my @players = (
    t::FakePlayer->new(id => 10, first_name => 'Zoe',   last_name => 'Zulu',  points => 50),
    t::FakePlayer->new(id => 20, first_name => 'Anna',  last_name => 'Alpha', points => 90),
    t::FakePlayer->new(id => 30, first_name => 'Brian', last_name => 'Beta',  points => 70),
);

my $picks = {
    10 => 63,
    20 => 45,
    30 => 63,
};
my $win_pct = {
    10 => 20.5,
    20 => 20.5,
    30 => 55.0,
};
my $projection_metrics = {
    winpct_by_player => $win_pct,
    podiumpct_by_player => {
        10 => 80.0,
        20 => 95.0,
        30 => 88.0,
    },
    maxpoints_by_player => {
        10 => 130,
        20 => 140,
        30 => 160,
    },
    avgscore_by_player => {
        10 => 100.1,
        20 => 120.9,
        30 => 119.4,
    },
    ups_by_player => {
        10 => 2,
        20 => 5,
        30 => 5,
    },
    cor_by_player => {
        10 => 11,
        20 => 9,
        30 => 9,
    },
    act_by_player => {
        10 => 2,
        20 => 1,
        30 => 3,
    },
    fi4_by_player => {
        10 => 1,
        20 => 1,
        30 => 2,
    },
    champion_name_by_player => {
        10 => 'duke',
        20 => '',
        30 => 'alabama',
    },
};

my $points_sorted = Bracket::Controller::Player::_sort_players(\@players, 'points', $picks);
is_deeply([ map { $_->id } @{$points_sorted} ], [20, 30, 10], 'points sort is default descending');

my $player_sorted = Bracket::Controller::Player::_sort_players(\@players, 'player', $picks);
is_deeply([ map { $_->id } @{$player_sorted} ], [20, 30, 10], 'player sort is alphabetical');

my $picks_sorted = Bracket::Controller::Player::_sort_players(\@players, 'picks', $picks);
is_deeply([ map { $_->id } @{$picks_sorted} ], [30, 10, 20], 'picks sort puts complete first then completed count desc');

my $dynamic_picks = {
    10 => 8,
    20 => 10,
    30 => 9,
};
my $dynamic_target_sorted = Bracket::Controller::Player::_sort_players(\@players, 'picks', $dynamic_picks, undef, 10);
is_deeply([ map { $_->id } @{$dynamic_target_sorted} ], [20, 30, 10], 'picks sort honors structure-derived completion target');

my $fallback_sorted = Bracket::Controller::Player::_sort_players(\@players, 'unknown', $picks);
is_deeply([ map { $_->id } @{$fallback_sorted} ], [20, 30, 10], 'unknown sort falls back to points');

my $winpct_sorted = Bracket::Controller::Player::_sort_players(\@players, 'winpct', $picks, $win_pct);
is_deeply([ map { $_->id } @{$winpct_sorted} ], [30, 20, 10], 'winpct sort uses projected win percent then points');

my $winpct_without_data = Bracket::Controller::Player::_sort_players(\@players, 'winpct', $picks);
is_deeply([ map { $_->id } @{$winpct_without_data} ], [20, 30, 10], 'winpct sort falls back to points when no projection data');

my $podiumpct_sorted = Bracket::Controller::Player::_sort_players(\@players, 'podiumpct', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$podiumpct_sorted} ], [20, 30, 10], 'podiumpct sort uses podium percent then win percent and points');

my $podiumpct_without_data = Bracket::Controller::Player::_sort_players(\@players, 'podiumpct', $picks);
is_deeply([ map { $_->id } @{$podiumpct_without_data} ], [20, 30, 10], 'podiumpct sort falls back to points when no projection data');

my $maxpoints_sorted = Bracket::Controller::Player::_sort_players(\@players, 'maxpoints', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$maxpoints_sorted} ], [30, 20, 10], 'maxpoints sort uses projection ceiling first');

my $maxpoints_without_data = Bracket::Controller::Player::_sort_players(\@players, 'maxpoints', $picks);
is_deeply([ map { $_->id } @{$maxpoints_without_data} ], [20, 30, 10], 'maxpoints sort falls back to points when no projection data');

my $avgscore_sorted = Bracket::Controller::Player::_sort_players(\@players, 'avgscore', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$avgscore_sorted} ], [20, 30, 10], 'avgscore sort uses projected average score');

my $avgscore_without_data = Bracket::Controller::Player::_sort_players(\@players, 'avgscore', $picks);
is_deeply([ map { $_->id } @{$avgscore_without_data} ], [20, 30, 10], 'avgscore sort falls back to points when no projection data');

my $ups_sorted = Bracket::Controller::Player::_sort_players(\@players, 'ups', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$ups_sorted} ], [20, 30, 10], 'ups sort uses upsets then correct then points');

my $cor_sorted = Bracket::Controller::Player::_sort_players(\@players, 'cor', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$cor_sorted} ], [10, 20, 30], 'cor sort uses correct then upsets then points');

my $act_sorted = Bracket::Controller::Player::_sort_players(\@players, 'act', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$act_sorted} ], [30, 10, 20], 'act sort uses active teams then correct then points');

my $fi4_sorted = Bracket::Controller::Player::_sort_players(\@players, 'fi4', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$fi4_sorted} ], [30, 10, 20], 'fi4 sort uses final4 active then active teams then points');

my $champion_sorted = Bracket::Controller::Player::_sort_players(\@players, 'champion', $picks, $projection_metrics);
is_deeply([ map { $_->id } @{$champion_sorted} ], [30, 10, 20], 'champion sort uses picked team name with blanks last');

is(Bracket::Controller::Player::_normalize_sort_by('WINPCT'), 'winpct', 'normalize accepts known sort case-insensitively');
is(Bracket::Controller::Player::_normalize_sort_by('bogus'), 'points', 'normalize falls back to points for unknown sort');
is(Bracket::Controller::Player::_normalize_sort_by(undef), 'points', 'normalize defaults to points');

done_testing();
