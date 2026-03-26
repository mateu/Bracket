package Bracket::Service::PickSaver;

use strict;
use warnings;

sub persist_pick_map {
    my ($class, $schema, $player_id, $pick_map) = @_;

    return { ok => 0, error => 'Missing schema' }     if !$schema;
    return { ok => 0, error => 'Invalid player id' }  if !$player_id;
    return { ok => 0, error => 'pick_map must be a hashref' }
        if !ref($pick_map) || ref($pick_map) ne 'HASH';

    my $error;
    {
        local $@;
        eval {
            $schema->txn_do(sub {
                foreach my $game_id (keys %{$pick_map}) {
                    my $team_id = $pick_map->{$game_id};
                    my $pick = $schema->resultset('Pick')->search({
                        player => $player_id,
                        game   => $game_id,
                    })->first;

                    if (defined $pick) {
                        $pick->pick($team_id);
                        $pick->update;
                    }
                    else {
                        $schema->resultset('Pick')->new({
                            player => $player_id,
                            game   => $game_id,
                            pick   => $team_id,
                        })->insert;
                    }
                }
            });
        };
        $error = $@;
    }

    if ($error) {
        return { ok => 0, error => "$error" };
    }

    return { ok => 1 };
}

1;
