package Bracket::Controller::Player;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Perl6::Junction qw/ any /;
use Bracket::Service::EquityProjection;

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
    # Picks made per region
    my $number_of_picks_per_region = $c->model('DBIC')->count_region_picks($player_id);
    $c->stash->{picks_per_region} = $number_of_picks_per_region;	
    # Number of Final 4 picks
    my $number_of_picks_per_final4 = $c->model('DBIC')->count_final4_picks($player_id);
    $c->stash->{picks_per_final4} = $number_of_picks_per_final4;	
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

	my $sort_by = lc($c->req->params->{sort} || 'points');
	$sort_by = 'points' if $sort_by !~ /\A(?:points|player|picks|winpct)\z/;
	$c->stash->{sort_by} = $sort_by;

	my @players = $c->model('DBIC::Player')->search( { active => 1 } )->all;
	my $picks_per_player = $c->model('DBIC')->count_player_picks;
	$c->stash->{picks_per_player} = $picks_per_player;
	my @regions = $c->model('DBIC::Region')->search({},{order_by => 'id'})->all;
	$c->stash->{regions} = \@regions;
    my $win_pct_by_player = {};

	if ($c->stash->{is_game_time}) {
      # Count of correct picks per player
      ($c->stash->{correct_picks_per_player}, $c->stash->{max_correct}) = $c->model('DBIC')->count_player_picks_correct;
      ($c->stash->{upset_picks_per_player}, $c->stash->{max_upsets}) = $c->model('DBIC')->count_player_picks_upset;
      ($c->stash->{teams_left_per_player}, $c->stash->{max_left}) = $c->model('DBIC')->count_player_teams_left;
      ($c->stash->{final4_teams_left_per_player}, $c->stash->{max_final4_left}) = $c->model('DBIC')->count_player_final4_teams_left;

      my $projection = Bracket::Service::EquityProjection->project(
          $c->model('DBIC')->schema,
          {
              iterations => 2000,
              seed       => 17,
          }
      );

      foreach my $row (@{$projection->{player_projections} || []}) {
          $win_pct_by_player->{$row->{player_id}} = ($row->{projected_first_pct} || 0) + 0;
      }

      my $max_win_pct = 0;
      foreach my $pct (values %{$win_pct_by_player}) {
          $max_win_pct = $pct if $pct > $max_win_pct;
      }

      $c->stash->{equity_projection} = $projection;
      $c->stash->{win_pct_by_player} = $win_pct_by_player;
      $c->stash->{max_win_pct} = $max_win_pct;
	}

	$c->stash->{players} = _sort_players(\@players, $sort_by, $picks_per_player, $win_pct_by_player);
}

sub _sort_players {
    my ($players, $sort_by, $picks_per_player, $win_pct_by_player) = @_;
    $players ||= [];
    $picks_per_player ||= {};
    $win_pct_by_player ||= {};
    $sort_by ||= 'points';

    if ($sort_by eq 'player') {
        return [ sort {
            lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
              || $b->points <=> $a->points
        } @{$players} ];
    }

    if ($sort_by eq 'picks') {
        return [ sort {
            my $a_count = $picks_per_player->{$a->id} || 0;
            my $b_count = $picks_per_player->{$b->id} || 0;
            my $a_complete = $a_count >= 63 ? 1 : 0;
            my $b_complete = $b_count >= 63 ? 1 : 0;

            $b_complete <=> $a_complete
              || $b_count <=> $a_count
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'winpct') {
        return [ sort {
            my $a_win = $win_pct_by_player->{$a->id} || 0;
            my $b_win = $win_pct_by_player->{$b->id} || 0;
            $b_win <=> $a_win
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    return [ sort {
        $b->points <=> $a->points
          || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
    } @{$players} ];
}


__PACKAGE__->meta->make_immutable;
1
