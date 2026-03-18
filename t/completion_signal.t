use strict;
use warnings;
use Test::More;

use lib qw(lib);
use Bracket::Service::CompletionSignal;

{
    package Local::CompletionSignalCtx;
    sub new {
        my $class = shift;
        return bless { flash => {} }, $class;
    }
    sub flash {
        my $self = shift;
        return $self->{flash};
    }
}

my $ctx_worked = Local::CompletionSignalCtx->new;
Bracket::Service::CompletionSignal->mark_terminal($ctx_worked, worked => 1);
is($ctx_worked->flash->{automation_worked}, 1, 'worked signal set on success');
is($ctx_worked->flash->{automation_done}, 1, 'done signal set on success');
is($ctx_worked->flash->{automation_state}, 'done', 'state set to done on success');

my $ctx_failed = Local::CompletionSignalCtx->new;
Bracket::Service::CompletionSignal->mark_terminal($ctx_failed, worked => 0);
is($ctx_failed->flash->{automation_worked}, 0, 'worked signal unset on failure');
is($ctx_failed->flash->{automation_done}, 1, 'done signal set on failure');
is($ctx_failed->flash->{automation_state}, 'failed', 'state set to failed on failure');

done_testing();
