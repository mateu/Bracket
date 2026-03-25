package Bracket::Service::ContinuityAudit;

use strict;
use warnings;

sub issues_for_schema {
    my ($class, $schema, %opts) = @_;

    return [] if !$schema;

    my $active_only = exists $opts{active_only} ? $opts{active_only} : 1;
    my %player_filter = $active_only ? (active => 1) : ();

    my %game_parents;
    my $game_graph_rs = $schema->resultset('GameGraph')->search({});
    while (my $game_graph = $game_graph_rs->next) {
        push @{ $game_parents{ $game_graph->game } }, $game_graph->parent_game;
    }

    my @issues;
    my @players = $schema->resultset('Player')->search(\%player_filter)->all;

    for my $player (@players) {
        my %picks = map { $_->get_column('game') => $_->get_column('pick') }
          $schema->resultset('Pick')->search({ player => $player->id })->all;

        for my $game_id (sort { $a <=> $b } grep { $_ >= 9 } keys %picks) {
            my $parents_ref = $game_parents{$game_id} || [];
            my @parents     = @{$parents_ref};
            next if !@parents;

            my @parent_winners = grep { defined $_ } map { $picks{$_} } @parents;
            next if @parent_winners < @parents;

            my %allowed = map { $_ => 1 } @parent_winners;
            next if $allowed{$picks{$game_id}};

            push @issues, {
                player_id       => $player->id,
                game_id         => $game_id,
                invalid_pick_id => $picks{$game_id},
                allowed_pick_ids => [@parent_winners],
            };
        }
    }

    return \@issues;
}

1;
