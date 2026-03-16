#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Bracket::Schema;

my $dsn  = $ENV{BRACKET_DSN}  || 'dbi:mysql:database=bracket_2026;host=127.0.0.1;port=3306';
my $user = $ENV{BRACKET_DB_USER} || 'root';
my $pass = $ENV{BRACKET_DB_PASSWORD} || '';

my $schema = Bracket::Schema->connect($dsn, $user, $pass);

my @players = $schema->resultset('Player')->search({ active => 1 })->all;
my $issues = 0;

for my $player (@players) {
    my %picks = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => $player->id })->all;

    for my $game_id (sort { $a <=> $b } grep { $_ >= 9 } keys %picks) {
        my @parents = map { $_->parent_game }
          $schema->resultset('GameGraph')->search({ game => $game_id })->all;
        next if !@parents;

        my @parent_winners = grep { defined $_ } map { $picks{$_} } @parents;
        next if @parent_winners < @parents;

        my %allowed = map { $_ => 1 } @parent_winners;
        if (!$allowed{$picks{$game_id}}) {
            $issues++;
            print join("\t",
                'player=' . $player->id,
                'game=' . $game_id,
                'pick=' . $picks{$game_id},
                'allowed=' . join(',', @parent_winners)
            ), "\n";
        }
    }
}

if (!$issues) {
    print "OK: no continuity issues found\n";
}
