package Bracket::Service::EditCutoff;

use strict;
use warnings;

use DateTime;

sub cutoff_time {
    my ($class, $config) = @_;

    my $cutoff = (ref($config) eq 'HASH') ? ($config->{edit_cutoff_time} || {}) : {};
    my $year = _int_or_default($cutoff->{year}, _int_or_default($config->{year}, DateTime->now(time_zone => 'UTC')->year));
    my $month = _int_or_default($cutoff->{month}, 3);
    my $day = _int_or_default($cutoff->{day}, 15);
    my $hour = _int_or_default($cutoff->{hour}, 12);
    my $minute = _int_or_default($cutoff->{minute}, 15);
    my $second = _int_or_default($cutoff->{second}, 0);
    my $time_zone = (defined $cutoff->{time_zone} && $cutoff->{time_zone} ne '') ? $cutoff->{time_zone} : 'US/Eastern';

    my $cutoff_time;
    my $ok = eval {
        $cutoff_time = DateTime->new(
            year      => $year,
            month     => $month,
            day       => $day,
            hour      => $hour,
            minute    => $minute,
            second    => $second,
            time_zone => $time_zone,
        );
        1;
    };

    if (!$ok) {
        $cutoff_time = DateTime->new(
            year      => _int_or_default($config->{year}, DateTime->now(time_zone => 'UTC')->year),
            month     => 3,
            day       => 15,
            hour      => 12,
            minute    => 15,
            second    => 0,
            time_zone => 'US/Eastern',
        );
    }

    return $cutoff_time;
}

sub is_game_time {
    my ($class, $config, $now) = @_;
    my $cutoff_time = $class->cutoff_time($config);
    $now ||= DateTime->now(time_zone => $cutoff_time->time_zone);
    return ($now > $cutoff_time) ? 1 : 0;
}

sub _int_or_default {
    my ($value, $default) = @_;
    return $default if !defined $value;
    return $value if "$value" =~ /\A\d+\z/;
    return $default;
}

1;
