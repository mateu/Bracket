package Bracket::Controller::Region;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Perl6::Junction qw/ any /;
use DateTime;
use Bracket::Service::BracketValidator;
use Bracket::Service::CompletionSignal;
use Bracket::Service::PickStatus;

my $PERFECT_BRACKET_MODE = 1;

=head1 NAME

Bracket::Controller::Region - Edit/View Regional picks


=cut

sub save_picks : Local {
    my ($self, $c, $region, $player_id) = @_;

    my $player_object = $c->model('DBIC::Player')->find({ id => $player_id });
    my $region_object = $c->model('DBIC::Region')->find($region);
    if (!$player_object || !$region_object) {
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->go('/error_404');
        return;
    }

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
        $c->flash->{status_msg} = 'Regional edits are closed';
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->response->redirect($c->uri_for($c->controller('Player')->action_for('home')) . "/${player_id}");
        return;
    }

    my $params = $c->request->params || {};
    my $validation = Bracket::Service::BracketValidator->validate_region_payload(
        $c->model('DBIC')->schema,
        $player_id,
        $region,
        $params,
    );

    if (!$validation->{ok}) {
        my $message = join('; ', @{$validation->{errors}});
        $c->flash->{status_msg} = "Save rejected: ${message}";
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->response->redirect($c->uri_for($c->controller('Region')->action_for('edit')) . "/${region}/${player_id}");
        return;
    }

    my $pick_map = $validation->{normalized_picks} || {};

    eval {
        $c->model('DBIC')->schema->txn_do(sub {
            foreach my $game (keys %{$pick_map}) {
                my $team = $pick_map->{$game};
                my ($pick) = $c->model('DBIC::Pick')->search({ player => $player_id, game => $game });
                if (defined $pick) {
                    $pick->pick($team);
                    $pick->update;
                }
                else {
                    my $new_pick = $c->model('DBIC::Pick')->new({ player => $player_id, game => $game, pick => $team });
                    $new_pick->insert;
                }
            }
        });
    };

    if ($@) {
        $c->flash->{status_msg} = 'Save failed due to a database error';
        Bracket::Service::CompletionSignal->mark_terminal($c, worked => 0);
        $c->response->redirect($c->uri_for($c->controller('Region')->action_for('edit')) . "/${region}/${player_id}");
        return;
    }

    $c->flash->{status_msg} = 'Regional picks saved';
    Bracket::Service::CompletionSignal->mark_terminal($c, worked => 1);
    $c->response->redirect(
        $c->uri_for($c->controller('Player')->action_for('home'))
        . "/${player_id}"
    );

    return;
}

sub view : Local {
    my ($self, $c, $region_id, $player_id) = @_;

    my $schema = $c->model('DBIC')->schema;
    my $player_picks = Bracket::Service::PickStatus->player_picks($schema, $player_id);
    my $class_for_all = Bracket::Service::PickStatus->classify_pick_rows($schema, $player_picks);

    my %picks;
    my %class_for;
    my $region_points = 0;
    my @show_regions;
    foreach my $player_pick (@{$player_picks}) {

        # Operate only on the current region
        if ($player_pick->pick->region->id == $region_id) {
            my $game_id = $player_pick->game->id;
            $class_for{$game_id} = $class_for_all->{$game_id};
            if ($class_for{$game_id} eq 'in') {
                # NOTE:  Formula to compute points for correct picks
                my $points_for_pick =
                  (5 + $player_pick->pick->seed * $player_pick->game->lower_seed) *
                  $player_pick->game->round;
                $region_points += $points_for_pick;
            }
            $picks{$game_id} = $player_pick->pick;
        }
    }
    $c->stash->{class_for}     = \%class_for;
    $c->stash->{picks}         = \%picks;
    $c->stash->{region_points} = $region_points;

    my $player = $c->model('DBIC::Player')->find($player_id);
    $c->stash->{player} = $player;
    my $region = $c->model('DBIC::Region')->find($region_id);
    $c->stash->{region}       = $region;
    $c->stash->{teams}        = $c->model('DBIC::Team')->search({region => $region_id});
    $c->stash->{regions}      = $c->model('DBIC::Region')->search({},{order_by => 'id'});
    $c->stash->{show_regions} = \@show_regions;
    $c->stash->{template}     = 'region/view_region_status.tt';

    return;
}

sub edit : Local {
    my ($self, $c, $region, $player) = @_;

    # Restrict edits to user or admin role.
    my @user_roles = $c->user->roles;
    $c->go('/error_404') if (($player != $c->user->id) && !('admin' eq any(@user_roles)));

    # Go to home if edits are attempted after closing time
    # NOTE: Put a player's id on this list and they can make edits after the cut-off.
    my @open_edit_ids = qw/ /;
    my $edit_allowed = 1 if ($c->user->id eq any(@open_edit_ids));
    if ( $c->stash->{is_game_time} && (!($c->stash->{is_admin} || $edit_allowed)) ) {
        $c->flash->{status_msg} = 'Regional edits are closed';
        $c->response->redirect($c->uri_for($c->controller('Player')->action_for('home')));
    }

    # Player picks
    my @picks = $c->model('DBIC::Pick')->search({ player => $player });
    my %picks;
    foreach my $pick (@picks) {
        $picks{ $pick->game->id } = $pick->pick;
    }
    $c->stash->{picks} = \%picks;

    # Player info
    my $player_object = $c->model('DBIC::Player')->find($player);
    my $player_name   = $player_object->first_name . ' ' . $player_object->last_name;
    $c->stash->{player}      = $player;
    $c->stash->{player_name} = $player_name;

    # Region object
    my $region_object = $c->model('DBIC::Region')->find($region);
    my $region_name   = $region_object->name;
    $c->stash->{region}      = $region;
    $c->stash->{region_name} = $region_name;

    # Teams
    $c->stash->{teams} = $c->model('DBIC::Team')->search({region => $region});
    

    $c->stash->{template} = 'region/edit_region_picks.tt';

    return;
}

=head1 AUTHOR

mateu x hunter

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
