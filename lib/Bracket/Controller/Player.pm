package Bracket::Controller::Player;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Perl6::Junction qw/ any /;

=head1 NAME

Bracket::Controller::Player - Individual and all player homes

=cut

sub home : Path('/player') {
	my ( $self, $c, $player_id ) = @_;

	$c->stash->{template} = 'player/home.tt';

	# If we pass a player id in exlicity we want to view that players home page.
	my $player;
	if ($player_id) {
		$player = $c->model('DBIC::Player')->find($player_id);
		$c->go('/error_404') if !$player;
	}
	else {
		$player    = $c->user;
		$player_id = $c->user->id;
	}
	$c->stash->{player}    = $player;
	$c->stash->{player_id} = $player_id;
	
	# Get regions 
	my @regions = $c->model('DBIC::Region')->search({},{order_by => 'id'})->all;
	$c->stash->{regions} = \@regions;
	
	return;
}

sub account : Global {
	my ( $self, $c ) = @_;

	$c->stash( template => 'player/account.tt', );
}

=head2 all 

View of all players.  Includes links to players picks
and score/status.

=cut

sub all : Global {
	my ( $self, $c ) = @_;
	
	$c->stash->{template} = 'player/all_home.tt';

	my @players = $c->model('DBIC::Player')->search( { active => 1 } )->all;
	$c->stash->{players} = \@players;
	my @regions = $c->model('DBIC::Region')->search({},{order_by => 'id'})->all;
	$c->stash->{regions} = \@regions;
}


__PACKAGE__->meta->make_immutable;
1
