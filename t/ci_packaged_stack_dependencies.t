use strict;
use warnings;
use Test::More;

my @required_modules = qw(
    Catalyst::Action::REST
);

for my $module (@required_modules) {
    use_ok($module);
}

done_testing();
