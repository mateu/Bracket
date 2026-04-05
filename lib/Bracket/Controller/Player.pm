package Bracket::Controller::Player;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Perl6::Junction qw/ any /;
use Bracket::Service::BracketStructure;
use Bracket::Service::EquityProjection;
use Bracket::Service::BracketStructure;

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

    my $pick_targets = Bracket::Service::BracketStructure->pick_targets(
        $c->model('DBIC')->schema
    );
    my $expected_total_picks = $pick_targets->{total_picks} || 63;
    my $expected_final4_picks = $pick_targets->{final4_picks} || 3;
    my $expected_region_picks_by_region = $pick_targets->{region_picks_by_region} || {};
    my %region_targets = map {
        my $region_id = $_->id;
        $region_id => (
            exists $expected_region_picks_by_region->{$region_id}
            ? $expected_region_picks_by_region->{$region_id}
            : 15
        )
    } @regions;
    $c->stash->{expected_total_picks} = $expected_total_picks;
    $c->stash->{expected_final4_picks} = $expected_final4_picks;
    $c->stash->{expected_region_picks_by_region} = \%region_targets;

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
	$sort_by = 'points' if $sort_by !~ /\A(?:points|player|picks|winpct|maxpoints|avgscore|podiumpct|ups|cor|act|fi4|champion)\z/;
	$c->stash->{sort_by} = $sort_by;

	my @players = $c->model('DBIC::Player')->search( { active => 1 } )->all;
	my $picks_per_player = $c->model('DBIC')->count_player_picks;
	$c->stash->{picks_per_player} = $picks_per_player;
    my $pick_targets = Bracket::Service::BracketStructure->pick_targets(
        $c->model('DBIC')->schema
    );
    my $expected_total_picks = $pick_targets->{total_picks} || 63;
    $c->stash->{expected_total_picks} = $expected_total_picks;
	my @regions = $c->model('DBIC::Region')->search({},{order_by => 'id'})->all;
	$c->stash->{regions} = \@regions;

    my $structure = Bracket::Service::BracketStructure->describe_bracket(
        $c->model('DBIC')->schema
    );
    my $championship_game_id = $structure->{championship_game_id};
    $c->stash->{championship_game_id} = $championship_game_id;

    my %champion_pick_by_player;
    my %champion_name_by_player;
    if ($championship_game_id) {
        my @champion_picks = $c->model('DBIC::Pick')->search({ game => $championship_game_id })->all;
        foreach my $pick (@champion_picks) {
            my $player_id = $pick->player->id;
            my $team = $pick->pick;
            $champion_pick_by_player{$player_id} = $team;
            $champion_name_by_player{$player_id} = lc($team->name || '');
        }
    }
    $c->stash->{champion_pick_by_player} = \%champion_pick_by_player;

    my $projection_metrics = {
        champion_name_by_player => \%champion_name_by_player,
    };

	if ($c->stash->{is_game_time}) {
      # Count of correct picks per player
      ($c->stash->{correct_picks_per_player}, $c->stash->{max_correct}) = $c->model('DBIC')->count_player_picks_correct;
      ($c->stash->{upset_picks_per_player}, $c->stash->{max_upsets}) = $c->model('DBIC')->count_player_picks_upset;
      ($c->stash->{teams_left_per_player}, $c->stash->{max_left}) = $c->model('DBIC')->count_player_teams_left;
      ($c->stash->{final4_teams_left_per_player}, $c->stash->{max_final4_left}) = $c->model('DBIC')->count_player_final4_teams_left;
      $projection_metrics->{cor_by_player} = $c->stash->{correct_picks_per_player} || {};
      $projection_metrics->{ups_by_player} = $c->stash->{upset_picks_per_player} || {};
      $projection_metrics->{act_by_player} = $c->stash->{teams_left_per_player} || {};
      $projection_metrics->{fi4_by_player} = $c->stash->{final4_teams_left_per_player} || {};

      my $projection = Bracket::Service::EquityProjection->project(
          $c->model('DBIC')->schema,
          {
              iterations => 2000,
              seed       => 17,
          }
      );

      foreach my $row (@{$projection->{player_projections} || []}) {
          next if !$row->{player_id};
          $projection_metrics->{winpct_by_player}{$row->{player_id}} = _numeric($row->{projected_first_pct});
          $projection_metrics->{podiumpct_by_player}{$row->{player_id}} = _numeric($row->{projected_podium_pct});
          $projection_metrics->{maxpoints_by_player}{$row->{player_id}} = _numeric($row->{max_possible_points});
          $projection_metrics->{avgscore_by_player}{$row->{player_id}} = _numeric($row->{projected_score_avg});
      }

      my $max_win_pct = _max_for_map($projection_metrics->{winpct_by_player});
      my $max_podium_pct = _max_for_map($projection_metrics->{podiumpct_by_player});
      my $max_possible_points = _max_for_map($projection_metrics->{maxpoints_by_player});
      my $max_projected_score = _max_for_map($projection_metrics->{avgscore_by_player});

      $c->stash->{equity_projection} = $projection;
      $c->stash->{win_pct_by_player} = $projection_metrics->{winpct_by_player} || {};
      $c->stash->{podium_pct_by_player} = $projection_metrics->{podiumpct_by_player} || {};
      $c->stash->{max_points_by_player} = $projection_metrics->{maxpoints_by_player} || {};
      $c->stash->{avg_score_by_player} = $projection_metrics->{avgscore_by_player} || {};
      $c->stash->{max_win_pct} = $max_win_pct || 0;
      $c->stash->{max_podium_pct} = $max_podium_pct || 0;
      $c->stash->{max_possible_points} = $max_possible_points || 0;
      $c->stash->{max_projected_score} = $max_projected_score || 0;
	}

	$c->stash->{players} = _sort_players(
        \@players,
        $sort_by,
        $picks_per_player,
        $projection_metrics,
        $expected_total_picks,
    );
}

sub _sort_players {
    my ($players, $sort_by, $picks_per_player, $projection_metrics, $expected_total_picks) = @_;
    $players ||= [];
    $picks_per_player ||= {};
    $projection_metrics ||= {};
    $sort_by ||= 'points';
    $expected_total_picks = 63 if !defined $expected_total_picks || $expected_total_picks !~ /^\d+$/ || $expected_total_picks < 1;

    my $win_pct_by_player = $projection_metrics->{winpct_by_player} || {};
    # Backward compatibility for legacy tests/callers that pass win-pct map directly.
    if (!exists $projection_metrics->{winpct_by_player}) {
        $win_pct_by_player = $projection_metrics;
    }
    my $podium_pct_by_player = $projection_metrics->{podiumpct_by_player} || {};
    my $max_points_by_player = $projection_metrics->{maxpoints_by_player} || {};
    my $avg_score_by_player = $projection_metrics->{avgscore_by_player} || {};
    my $ups_by_player = $projection_metrics->{ups_by_player} || {};
    my $cor_by_player = $projection_metrics->{cor_by_player} || {};
    my $act_by_player = $projection_metrics->{act_by_player} || {};
    my $fi4_by_player = $projection_metrics->{fi4_by_player} || {};
    my $champion_name_by_player = $projection_metrics->{champion_name_by_player} || {};

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
            my $a_complete = $a_count >= $expected_total_picks ? 1 : 0;
            my $b_complete = $b_count >= $expected_total_picks ? 1 : 0;

            $b_complete <=> $a_complete
              || $b_count <=> $a_count
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'winpct') {
        return [ sort {
            my $a_win = _numeric($win_pct_by_player->{$a->id});
            my $b_win = _numeric($win_pct_by_player->{$b->id});
            $b_win <=> $a_win
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'podiumpct') {
        return [ sort {
            my $a_podium = _numeric($podium_pct_by_player->{$a->id});
            my $b_podium = _numeric($podium_pct_by_player->{$b->id});
            my $a_win = _numeric($win_pct_by_player->{$a->id});
            my $b_win = _numeric($win_pct_by_player->{$b->id});
            $b_podium <=> $a_podium
              || $b_win <=> $a_win
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'maxpoints') {
        return [ sort {
            my $a_max = _numeric($max_points_by_player->{$a->id});
            my $b_max = _numeric($max_points_by_player->{$b->id});
            my $a_win = _numeric($win_pct_by_player->{$a->id});
            my $b_win = _numeric($win_pct_by_player->{$b->id});
            $b_max <=> $a_max
              || $b_win <=> $a_win
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'avgscore') {
        return [ sort {
            my $a_avg = _numeric($avg_score_by_player->{$a->id});
            my $b_avg = _numeric($avg_score_by_player->{$b->id});
            my $a_win = _numeric($win_pct_by_player->{$a->id});
            my $b_win = _numeric($win_pct_by_player->{$b->id});
            $b_avg <=> $a_avg
              || $b_win <=> $a_win
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'ups') {
        return [ sort {
            _numeric($ups_by_player->{$b->id}) <=> _numeric($ups_by_player->{$a->id})
              || _numeric($cor_by_player->{$b->id}) <=> _numeric($cor_by_player->{$a->id})
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'cor') {
        return [ sort {
            _numeric($cor_by_player->{$b->id}) <=> _numeric($cor_by_player->{$a->id})
              || _numeric($ups_by_player->{$b->id}) <=> _numeric($ups_by_player->{$a->id})
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'act') {
        return [ sort {
            _numeric($act_by_player->{$b->id}) <=> _numeric($act_by_player->{$a->id})
              || _numeric($cor_by_player->{$b->id}) <=> _numeric($cor_by_player->{$a->id})
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'fi4') {
        return [ sort {
            _numeric($fi4_by_player->{$b->id}) <=> _numeric($fi4_by_player->{$a->id})
              || _numeric($act_by_player->{$b->id}) <=> _numeric($act_by_player->{$a->id})
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    if ($sort_by eq 'champion') {
        return [ sort {
            my $a_name = $champion_name_by_player->{$a->id} || '';
            my $b_name = $champion_name_by_player->{$b->id} || '';
            ($a_name eq '') <=> ($b_name eq '')
              || $a_name cmp $b_name
              || $b->points <=> $a->points
              || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
        } @{$players} ];
    }

    return [ sort {
        $b->points <=> $a->points
          || lc($a->first_name . ' ' . $a->last_name) cmp lc($b->first_name . ' ' . $b->last_name)
    } @{$players} ];
}

sub _numeric {
    my ($value) = @_;
    return 0 if !defined $value || $value eq '';
    return $value + 0;
}

sub _max_for_map {
    my ($map) = @_;
    $map ||= {};
    my $max = 0;
    foreach my $value (values %{$map}) {
        my $numeric_value = _numeric($value);
        $max = $numeric_value if $numeric_value > $max;
    }
    return $max;
}


__PACKAGE__->meta->make_immutable;
1
