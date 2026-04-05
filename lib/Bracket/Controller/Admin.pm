package Bracket::Controller::Admin;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Perl6::Junction qw/ any /;
use Bracket::Service::EquityProjection;
use Bracket::Service::ContinuityAudit;
use Bracket::Service::BracketStructure;

=head1 Name

Bracket::Controller::Admin - Functions for admin users.
  
=head1 Description

Controller for admin functions:

* Update player points
* Mark the round teams go out
* Check which wins are by a lower seed

=head1 Methods

=cut

sub auto : Private {
    my ($self, $c) = @_;

    # Restrict controller to admin role
    my @user_roles = $c->user->roles;

    if (!$c->stash->{is_admin}) {
        $c->go('/error_404');
        return 0;
    }
    else { return 1; }
}

sub update_player_points : Global {
    my ($self, $c) = @_;

    $c->stash->{template} = 'player/all_home.tt';
    my @players = $c->model('DBIC::Player')->all;

    # Get player scores
    foreach my $player (@players) {

        # Avoid non active players
        next if $player->active == 0;

        # Get total points, and regional points
        my $points_ref = $c->forward('player_points', [ $player->id ]);
        $player->points($points_ref->[0] || 0);
        $player->update;
        foreach my $region_id (1 .. 4) {
            my $region_score = $c->model('DBIC::RegionScore')->update_or_create(
                {
                    player => $player->id,
                    region => $region_id,
                    points => $points_ref->[1]->{$region_id} || 0
                }
            );
            $region_score->update;
        }
    }
    $c->stash->{players}    = \@players;
    $c->flash->{status_msg} = 'Scores Updated';
    $c->response->redirect($c->uri_for($c->controller('Player')->action_for('all')));
    return;
}

sub player_points : Private {
    my ($self, $c, $player) = @_;

    # Determine player total running score.
    my @player_picks = $c->model('DBIC::Pick')->search({ player => $player });
    my $total_player_points = 0;
    my $points_for_region;
    foreach my $player_pick (@player_picks) {

        # Compare player pick to actual winner for the perfect player bracket
        # Build the css class name accordingly
        my ($winning_pick) =
          $c->model('DBIC::Pick')->search({ player => 1, game => $player_pick->game->id });
        if (defined $winning_pick) {
            if ($winning_pick->pick->id == $player_pick->pick->id) {

                # Compute points for correct pick
                # Formula
                my $points_for_pick =
                  (5 + $player_pick->pick->seed * $player_pick->game->lower_seed);

                # Championship game has round multiplier of 10.
                if ($player_pick->game->round == 6) {
                    $points_for_pick *= 10;
                }

                # All other games have round multiplier of round number.
                else {
                    $points_for_pick *= $player_pick->game->round;
                }
                $total_player_points                                   += $points_for_pick;
                $points_for_region->{ $player_pick->pick->region->id } += $points_for_pick;
            }
        }
    }

    return [ $total_player_points, $points_for_region ];
}

# Quality Assurance to check that lower seeds are marked correctly.
sub qa : Global {
    my ($self, $c) = @_;
    my @played_games = $c->model('DBIC::Pick')->search({ player => 1 }, { order_by => 'game' });
    $c->stash->{played_games} = \@played_games;
    $c->stash->{template}     = 'admin/lower_seeds.tt';
}

sub continuity_audit : Global {
    my ($self, $c) = @_;

    my $issues = Bracket::Service::ContinuityAudit->issues_for_schema(
        $c->model('DBIC')->schema
    );

    $c->stash->{continuity_issues} = $issues;
    $c->stash->{template}          = 'admin/continuity_audit.tt';
}

sub incomplete_submissions : Global {
    my ($self, $c) = @_;

    my $pick_targets = Bracket::Service::BracketStructure->pick_targets(
        $c->model('DBIC')->schema
    );
    my $expected_total_picks = $pick_targets->{total_picks} || 63;
    my $expected_final4_picks = $pick_targets->{final4_picks} || 3;
    my $expected_region_picks_by_region = $pick_targets->{region_picks_by_region} || {};
    my @region_ids = sort { $a <=> $b } keys %{$expected_region_picks_by_region};
    if (!@region_ids) {
        @region_ids = (1 .. 4);
        $expected_region_picks_by_region = {
            map { $_ => 15 } @region_ids
        };
    }

    my %region_name_for_id = map {
        $_->id => $_->name
    } $c->model('DBIC')->schema->resultset('Region')->search({})->all;

    my $total_picks_by_player = $c->model('DBIC')->count_player_picks || {};
    my @active_players = $c->model('DBIC::Player')->search(
        {
            active => 1,
            id     => { '!=' => 1 },
        },
        {
            order_by => [qw/last_name first_name id/],
        }
    )->all;

    my @incomplete_submissions;
    foreach my $player (@active_players) {
        my $player_id = $player->id;
        my $total_picks = $total_picks_by_player->{$player_id} || 0;
        next if $total_picks >= $expected_total_picks;

        my $region_counts = $c->model('DBIC')->count_region_picks($player_id) || {};
        my $final4_count = $c->model('DBIC')->count_final4_picks($player_id) || 0;

        push @incomplete_submissions, {
            player_id          => $player_id,
            player_name        => join(' ', grep { defined && length } $player->first_name, $player->last_name),
            username           => $player->username,
            total_picks        => $total_picks,
            missing_total      => $expected_total_picks - $total_picks,
            region_counts      => $region_counts,
            final4_picks       => $final4_count,
        };
    }

    $c->stash->{expected_total_picks}  = $expected_total_picks;
    $c->stash->{expected_final4_picks} = $expected_final4_picks;
    $c->stash->{expected_region_picks_by_region} = $expected_region_picks_by_region;
    $c->stash->{region_ids} = \@region_ids;
    $c->stash->{region_name_for_id} = \%region_name_for_id;
    $c->stash->{incomplete_submissions} = \@incomplete_submissions;
    $c->stash->{template}               = 'admin/incomplete_submissions.tt';
}

sub update_points : Global {
    my ($self, $c) = @_;
    my $points = $c->model('DBIC')->update_points;
    #    $c->flash->{status_msg} = 'Scores Updated in ' . sprintf("%0.1f milliseconds", $points[0]*1000);
    $c->flash->{status_msg} = $points;
    $c->response->redirect($c->uri_for($c->controller('Player')->action_for('all')));
    return;
}

=head2 round_out

Mark the round teams go out.

=cut

sub round_out : Global : ActionClass('REST') {
    my ($self, $c) = @_;

    $c->stash->{template} = 'admin/round_out.tt';
    my @teams = $c->model('DBIC::Team')->all;
    $c->stash(teams => \@teams);
}

sub round_out_GET {}

sub round_out_POST {
    my  ($self, $c) = @_;
    
    foreach my $team (@{$c->stash->{teams}}) {
        $team->update({ round_out => $c->request->body_parameters->{$team->id} });
    }
}

=head2 round_out_unmarked

Show only the teams that havent' been marked out yet.

=cut

sub round_out_unmarked : Global : ActionClass('REST') {
    my ($self, $c) = @_;
    $c->stash->{template} = 'admin/round_out_unmarked.tt';
    my @teams = $c->model('DBIC::Team')->search({round_out => 7})->all;
    $c->stash(teams => \@teams);
}
sub round_out_unmarked_GET {}

sub round_out_unmarked_POST {
    my  ($self, $c) = @_;
    
    foreach my $team (@{$c->stash->{teams}}) {
        $team->update({ round_out => $c->request->body_parameters->{$team->id} });
    }
    $c->response->redirect($c->uri_for($c->controller('Player')->action_for('home')));
    return;
}

use constant MAX_SEED => 2**31 - 1;

sub equity_report : Global {
    my ($self, $c) = @_;

    my $iterations = $c->req->params->{iterations};
    $iterations = 4000 if !defined $iterations || $iterations !~ /^\d+$/;
    $iterations = 100 if $iterations < 100;
    $iterations = 20000 if $iterations > 20000;

    my $seed = $c->req->params->{seed};
    $seed = 17 if !defined $seed || $seed !~ /^\d+$/;
    $seed = 1        if $seed < 1;
    $seed = MAX_SEED if $seed > MAX_SEED;

    my $projection = Bracket::Service::EquityProjection->project(
        $c->model('DBIC')->schema,
        {
            iterations => $iterations,
            seed       => $seed,
        }
    );

    $c->stash->{projection} = $projection;
    $c->stash->{projection_iterations} = $iterations;
    $c->stash->{projection_seed} = $seed;
    $c->stash->{template} = 'admin/equity_report.tt';
}

__PACKAGE__->meta->make_immutable;
1
