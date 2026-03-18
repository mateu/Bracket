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

my $points_sorted = Bracket::Controller::Player::_sort_players(\@players, 'points', $picks);
is_deeply([ map { $_->id } @{$points_sorted} ], [20, 30, 10], 'points sort is default descending');

my $player_sorted = Bracket::Controller::Player::_sort_players(\@players, 'player', $picks);
is_deeply([ map { $_->id } @{$player_sorted} ], [20, 30, 10], 'player sort is alphabetical');

my $picks_sorted = Bracket::Controller::Player::_sort_players(\@players, 'picks', $picks);
is_deeply([ map { $_->id } @{$picks_sorted} ], [30, 10, 20], 'picks sort puts complete first then completed count desc');

my $fallback_sorted = Bracket::Controller::Player::_sort_players(\@players, 'unknown', $picks);
is_deeply([ map { $_->id } @{$fallback_sorted} ], [20, 30, 10], 'unknown sort falls back to points');

done_testing();
