use strict;
use warnings;

use Test::More;
use DateTime;

use Bracket::Service::EditCutoff;
use Bracket::Controller::Root;

my $cutoff = Bracket::Service::EditCutoff->cutoff_time({
    edit_cutoff_time => {
        year      => 2026,
        month     => 3,
        day       => 19,
        hour      => 12,
        minute    => 15,
        second    => 0,
        time_zone => 'US/Eastern',
    },
});

is($cutoff->year, 2026, 'configured year is used');
is($cutoff->month, 3, 'configured month is used');
is($cutoff->day, 19, 'configured day is used');
is($cutoff->hour, 12, 'configured hour is used');
is($cutoff->minute, 15, 'configured minute is used');
is($cutoff->time_zone->name, 'America/New_York', 'configured timezone is canonicalized');

my $defaulted = Bracket::Service::EditCutoff->cutoff_time({ year => 2032 });
is($defaulted->year, 2032, 'fallback uses configured app year when cutoff block is missing');
is($defaulted->month, 3, 'fallback month is March');
is($defaulted->day, 15, 'fallback day is 15th');
is($defaulted->hour, 12, 'fallback hour is noon Eastern');
is($defaulted->minute, 15, 'fallback minute is 15');
is($defaulted->time_zone->name, 'America/New_York', 'fallback timezone is Eastern');

my $malformed = Bracket::Service::EditCutoff->cutoff_time({
    year => 2035,
    edit_cutoff_time => {
        year      => 2035,
        month     => 99,
        day       => 77,
        hour      => 'nope',
        minute    => 123,
        second    => 0,
        time_zone => 'Not/AZone',
    },
});
is($malformed->year, 2035, 'malformed cutoff falls back to safe year');
is($malformed->month, 3, 'malformed cutoff falls back to safe month');
is($malformed->day, 15, 'malformed cutoff falls back to safe day');
is($malformed->time_zone->name, 'America/New_York', 'malformed cutoff falls back to safe timezone');

my $before = DateTime->new(
    year      => 2026,
    month     => 3,
    day       => 19,
    hour      => 12,
    minute    => 14,
    second    => 59,
    time_zone => 'US/Eastern',
);

my $after = DateTime->new(
    year      => 2026,
    month     => 3,
    day       => 19,
    hour      => 12,
    minute    => 15,
    second    => 1,
    time_zone => 'US/Eastern',
);

ok(!Bracket::Service::EditCutoff->is_game_time({ edit_cutoff_time => {
    year => 2026, month => 3, day => 19, hour => 12, minute => 15, second => 0, time_zone => 'US/Eastern'
}}, $before), 'before cutoff is not game time');

ok(Bracket::Service::EditCutoff->is_game_time({ edit_cutoff_time => {
    year => 2026, month => 3, day => 19, hour => 12, minute => 15, second => 0, time_zone => 'US/Eastern'
}}, $after), 'after cutoff is game time');

{
    package TestContext;
    sub new { my ($class, $config) = @_; bless { config => $config }, $class }
    sub config { $_[0]->{config} }
}

my $root = bless {}, 'Bracket::Controller::Root';
my $from_root = $root->edit_cutoff_time(TestContext->new({ year => 2031 }));
is($from_root->year, 2031, 'Root edit_cutoff_time delegates to cutoff service');


done_testing();
