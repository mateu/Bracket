use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Bracket' }
BEGIN { use_ok 'Bracket::Controller::Rounds' }

ok( request('/rounds')->is_success, 'Request should succeed' );


