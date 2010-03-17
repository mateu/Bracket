use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Bracket' }
BEGIN { use_ok 'Bracket::Controller::Player' }

ok( request('/register')->is_success, 'Request should succeed' );


