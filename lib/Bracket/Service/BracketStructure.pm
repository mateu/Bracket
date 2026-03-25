package Bracket::Service::BracketStructure;

use strict;
use warnings;

sub describe_bracket {
    my ($class, $schema) = @_;
    return {} if !$schema;

    my %parents_by_game;
    my %children_by_parent;

    my @edges = $schema->resultset('GameGraph')->search({})->all;
    foreach my $edge (@edges) {
        next if !defined $edge->game || !defined $edge->parent_game;
        push @{$parents_by_game{$edge->game}}, $edge->parent_game;
        push @{$children_by_parent{$edge->parent_game}}, $edge->game;
    }

    my @games = $schema->resultset('Game')->search({})->all;
    return {} if !@games;

    my %round_for = map { $_->id => $_->round } @games;

    my @roots = grep { !exists $children_by_parent{$_->id} } @games;
    @roots = @games if !@roots;

    my ($championship) = sort {
        ($b->round <=> $a->round) || ($b->id <=> $a->id)
    } @roots;
    return {} if !$championship;

    my $championship_game = $championship->id;
    my @semifinal_games = sort { $a <=> $b } @{$parents_by_game{$championship_game} || []};
    my @final4_games = sort { $a <=> $b } (@semifinal_games, $championship_game);

    my %regional_final_games = map { $_ => 1 }
      map { @{$parents_by_game{$_} || []} } @semifinal_games;

    my %region_for_game;
    foreach my $game_id (keys %regional_final_games) {
        my @regions = _regions_for_game($schema, $game_id, \%parents_by_game, \%region_for_game);
        next if @regions != 1;
        $region_for_game{$game_id} = $regions[0];
    }

    my %region_winner_games_by_region;
    foreach my $game_id (keys %regional_final_games) {
        my $region_id = $region_for_game{$game_id};
        next if !defined $region_id;
        $region_winner_games_by_region{$region_id} = $game_id;
    }

    return {
        championship_game             => $championship_game,
        semifinal_games               => \@semifinal_games,
        final4_games                  => \@final4_games,
        region_winner_games_by_region => \%region_winner_games_by_region,
        round_for_game                => \%round_for,
    };
}

sub final4_game_ids {
    my ($class, $schema) = @_;
    my $desc = $class->describe_bracket($schema);
    return $desc->{final4_games} || [];
}

sub region_winner_games_by_region {
    my ($class, $schema) = @_;
    my $desc = $class->describe_bracket($schema);
    return $desc->{region_winner_games_by_region} || {};
}

sub _regions_for_game {
    my ($schema, $game_id, $parents_by_game, $cache) = @_;

    if (exists $cache->{$game_id}) {
        my $cached = $cache->{$game_id};
        return ref $cached eq 'ARRAY' ? @{$cached} : ($cached);
    }

    my @parents = @{$parents_by_game->{$game_id} || []};
    if (!@parents) {
        my %regions;
        my @slots = $schema->resultset('GameTeamGraph')->search({ game => $game_id })->all;
        foreach my $slot (@slots) {
            my $team = $schema->resultset('Team')->find({ id => $slot->team });
            next if !$team || !$team->region;
            $regions{$team->region->id} = 1;
        }
        my @region_ids = sort { $a <=> $b } keys %regions;
        $cache->{$game_id} = \@region_ids;
        return @region_ids;
    }

    my %regions;
    foreach my $parent (@parents) {
        my @parent_regions = _regions_for_game($schema, $parent, $parents_by_game, $cache);
        $regions{$_} = 1 for @parent_regions;
    }

    my @region_ids = sort { $a <=> $b } keys %regions;
    $cache->{$game_id} = \@region_ids;
    return @region_ids;
}

1;
