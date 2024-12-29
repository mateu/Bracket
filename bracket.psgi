#!/usr/bin/env perl
use strict;
use warnings;
use Plack::Builder;
use Bracket;

my $app = Bracket->psgi_app(@_);


# START NOTE: One can start this script from the parent directory like so:
# plackup -s Standalone::Prefork script/bracket.psgi
# This requires the installation of Plack (cpan Plack).
