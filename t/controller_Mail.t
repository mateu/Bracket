use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Bracket' }
BEGIN { use_ok 'Bracket::Controller::Mail' }

ok( request('/email_reset_password_link')->is_success, 'Request should succeed' );


