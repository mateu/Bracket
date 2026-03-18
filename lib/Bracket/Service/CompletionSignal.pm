package Bracket::Service::CompletionSignal;

use strict;
use warnings;

sub mark_terminal {
    my ($class, $c, %args) = @_;

    return if !$c;

    my $worked = $args{worked} ? 1 : 0;
    my $flash = $c->flash;
    $flash->{automation_worked} = $worked;
    $flash->{automation_done}   = 1;
    $flash->{automation_state}  = $worked ? 'done' : 'failed';
}

1;
