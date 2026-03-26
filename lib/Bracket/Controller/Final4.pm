package Bracket::Controller::Final4;
use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Perl6::Junction qw/ any /;
use Data::Dumper::Concise;
use Bracket::Service::BracketValidator;
use Bracket::Service::CompletionSignal;
use Bracket::Service::PickSaver;

=head1 NAME

Bracket::Controller::Final4 - Edit/View Final 4 Picks

=cut

my %region_winner_picks = (
    1 => 15,
    2 => 30,
    3 => 45,
    4 => 60,
);

sub make : Local {
    my ($self, $c, $player_id) = @_;

    # Restrict edits to user or admin role.
    my @user_roles = $c->user->roles;
    if (($player_id != $c->user->id) && !('admin' eq any(@user_roles))) {
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->go('/error_404');
        return;
    }

    my $player = $c->model('DBIC::Player')->find($player_id);
    $c->stash->{player} = $player;

    # Get the player's regional winner picks.  Later we deal w/ whether they actually won or not.
    # region_id => game_id
    foreach my $region_id (keys %region_winner_picks) {
        my $region_name = 'region' . "_${region_id}";
        my $game        = $region_winner_picks{$region_id};
        $c->stash->{$region_name} =
          $c->model('DBIC::Pick')->search({ player => $player_id, game => $game })->first;
    }

    # Get all player picks for loading when in edit of existing picks mode
    my @picks = $c->model('DBIC::Pick')->search({ player => $player_id });
    my %picks;
    foreach my $pick (@picks) {
        $picks{ $pick->game->id } = $pick->pick;
    }
    $c->stash->{picks} = \%picks;

    # Create Class for Final Four Teams
    my %class_for;
    foreach my $player_pick (@picks) {
        my ($winning_pick) =
          $c->model('DBIC::Pick')->search({ player => 1, game => $player_pick->game->id });
        if (defined $winning_pick) {
            if ($winning_pick->pick->id == $player_pick->pick->id) {
                $class_for{ $player_pick->game->id } = 'in';
            }
            else {
                $class_for{ $player_pick->game->id } = 'out';
            }
        }
        else {
            if ($player_pick->game->round >= $player_pick->pick->round_out) {

                #if ($player_pick->game == 63) {
#                warn "round: " . $player_pick->game->round . "\n";
#                warn "round_out: " . $player_pick->pick->round_out . "\n";

                #}
                $class_for{ $player_pick->game->id } = 'out';
            }
            else {
                $class_for{ $player_pick->game->id } = 'pending';
            }
        }
    }
    $c->stash->{class_for} = \%class_for;

    # Inform to load final 4 javascript
    $c->stash->{final_4_javascript} = 1;
    $c->stash->{template}           = 'final4/make_final4_picks.tt';

    return;
}

sub save_picks : Local {
    my ($self, $c, $player_id) = @_;

    my $player = $c->model('DBIC::Player')->find($player_id);
    if (!$player) {
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->go('/error_404');
        return;
    }
    $c->stash->{player}    = $player;
    $c->stash->{player_id} = $player_id;

    # Restrict saves to user or admin role.
    my @user_roles = $c->user->roles;
    if (($player_id != $c->user->id) && !('admin' eq any(@user_roles))) {
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->go('/error_404');
        return;
    }

    # Enforce edit cutoff at save time too.
    my @open_edit_ids = qw/ /;
    my $edit_allowed = 1 if ($c->user->id eq any(@open_edit_ids));
    if ( $c->stash->{is_game_time} && (!($c->stash->{is_admin} || $edit_allowed)) ) {
        $c->flash->{status_msg} = 'Final Four edits are closed';
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->response->redirect($c->uri_for($c->controller('Player')->action_for('home')) . "/${player_id}");
        return;
    }

    my $params = $c->request->params || {};
    my $validation = Bracket::Service::BracketValidator->validate_final4_payload(
        $c->model('DBIC')->schema,
        $player_id,
        $params,
    );

    if (!$validation->{ok}) {
        my $message = join('; ', @{$validation->{errors}});
        $c->flash->{status_msg} = "Save rejected: ${message}";
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->response->redirect($c->uri_for($c->controller('Final4')->action_for('make')) . "/${player_id}");
        return;
    }

    my $pick_map = $validation->{normalized_picks} || {};
    my $save_result = Bracket::Service::PickSaver->persist_pick_map(
        $c->model('DBIC')->schema,
        $player_id,
        $pick_map,
    );

    if (!$save_result->{ok}) {
        $c->flash->{status_msg} = 'Save failed due to a database error';
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->response->redirect($c->uri_for($c->controller('Final4')->action_for('make')) . "/${player_id}");
        return;
    }

    $c->flash->{status_msg} = 'Final Four picks saved';
    Bracket::Service::CompletionSignal->mark_terminal($c, worked => 1);
    $c->response->redirect(
        $c->uri_for($c->controller('Player')->action_for('home'))
        . "/${player_id}"
    );

    return;
}

sub view : Local {
    my ($self, $c, $player_id) = @_;

    my $player = $c->model('DBIC::Player')->find($player_id);
    $c->stash->{player} = $player;

    # Get the player's regional winner picks.
    foreach my $region_id (keys %region_winner_picks) {
        my $region_name = 'region' . "_${region_id}";
        my $game        = $region_winner_picks{$region_id};
        $c->stash->{$region_name} =
          $c->model('DBIC::Pick')->search({ player => $player_id, game => $game })->first;
    }

    # Get all player picks for loading when in edit of existing picks mode
    my @picks = $c->model('DBIC::Pick')->search({ player => $player_id });
    my %picks;
    foreach my $pick (@picks) {
        $picks{ $pick->game->id } = $pick->pick;
    }
    $c->stash->{picks} = \%picks;

    # Create Class for Final Four Teams
    my %class_for;
    foreach my $player_pick (@picks) {
        my ($winning_pick) =
          $c->model('DBIC::Pick')->search({ player => 1, game => $player_pick->game->id });
        if (defined $winning_pick) {
            if ($winning_pick->pick->id == $player_pick->pick->id) {
                $class_for{ $player_pick->game->id } = 'in';
            }
            else {
                $class_for{ $player_pick->game->id } = 'out';
            }
        }
        else {
            if ($player_pick->game->round >= $player_pick->pick->round_out) {
                $class_for{ $player_pick->game->id } = 'out';
            }
            else {
                $class_for{ $player_pick->game->id } = 'pending';
            }
        }
    }
    $c->stash->{class_for} = \%class_for;
    $c->stash->{regions}      = $c->model('DBIC::Region')->search({},{order_by => 'id'});

    # Turn off javascript
    $c->stash->{no_javascript} = 1;
    $c->stash->{template}      = 'final4/view_final4_picks.tt';
    return;
}

=head1 AUTHOR

mateu x hunter

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
