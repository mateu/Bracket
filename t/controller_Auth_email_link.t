use strict;
use warnings;
use Test::More;

use Bracket::Controller::Auth;

{
    package TestRequest;
    sub new { my ($class, $base) = @_; return bless { base => $base }, $class; }
    sub base { return $_[0]->{base}; }
}

{
    package TestContext;
    sub new {
        my ($class, $config, $base) = @_;
        return bless {
            config  => $config || {},
            request => TestRequest->new($base || 'http://localhost/'),
        }, $class;
    }

    sub config  { return $_[0]->{config}; }
    sub request { return $_[0]->{request}; }
}

my $controller = bless {}, 'Bracket::Controller::Auth';

{
    my $captured;
    local *Bracket::Controller::Auth::try_to_sendmail = sub {
        ($captured) = @_;
        return 1;
    };

    my $context = TestContext->new(
        {
            password_reset_email => {
                from    => 'no-reply@bracket.test',
                subject => 'Reset your bracket password',
            },
        },
        'https://bracket.test/',
    );

    $controller->email_link($context, 'player@bracket.test', 'token123_2');

    ok($captured, 'email is built and handed to sender');
    is($captured->header('To'), 'player@bracket.test', 'email targets requested recipient');
    is($captured->header('From'), 'no-reply@bracket.test', 'from address comes from config');
    is($captured->header('Subject'), 'Reset your bracket password', 'subject comes from config');
    like(
        $captured->body,
        qr{https://bracket\.test/reset_password\?reset_password_token=token123_2},
        'body contains reset token link'
    );
}

{
    my $captured;
    local *Bracket::Controller::Auth::try_to_sendmail = sub {
        ($captured) = @_;
        return 1;
    };

    my $context = TestContext->new({}, 'http://localhost/');

    $controller->email_link($context, 'fallback@bracket.test', 'token456_9');

    is($captured->header('From'), 'hunter@huntana.com', 'fallback from address preserves legacy default');
    is($captured->header('Subject'), 'Reset password link', 'fallback subject preserves legacy default');
}

done_testing();
