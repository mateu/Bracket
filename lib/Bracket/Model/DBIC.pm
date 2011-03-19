package Bracket::Model::DBIC;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(schema_class => 'Bracket::Schema',);

=head2 update_points

SQL update of points that is way faster than player_points action in Admin.
DRAWBACK: only tested on MySQL, may be MySQL specfic update.
SOLUTION: Find DBIC way of doing it?  Use sub-query.

=cut

sub update_points {
    my $self    = shift;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
                update player player, 
                (
                select  player_picks.player,
                        sum(game.round*(5 + game.lower_seed*team.seed)) as points
                  from picks player_picks, picks perfect_picks, game game, team team
                 where perfect_picks.pick   = player_picks.pick 
                   and perfect_picks.game   = player_picks.game 
                   and player_picks.game    = game.id
                   and player_picks.pick    = team.id
                   and perfect_picks.player = 1
                   group by player_picks.player
                )  computed_player_points
                set player.points = computed_player_points.points
                where player.id = computed_player_points.player
                ;'
            );
            $sth->execute();
        }
    );
}

=heads2 count_region_picks

Count up how many picks a player has made for each region.
Displayed on Player home page.

=cut

sub count_region_picks {
    my ($self, $player_id) = @_;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select region.id, count(*) from picks  
            join team on picks.pick = team.id  
            join region on team.region = region.id  
            join game on picks.game = game.id  
            where game.round < 5 and player = ? 
            group by region.id
            ;'
            );
            $sth->execute($player_id) or die $sth->errstr;;
            my $picks_per_region = { 1 => 0, 2 => 0, 3 => 0, 4 => 0 };
            my $result = $sth->fetchall_arrayref;
            foreach my $row (@{$result}) {
                $picks_per_region->{$row->[0]} = $row->[1];
            }
            return $picks_per_region;
        }
    );
}

=heads2 count_player_picks

Count up how many picks a player has made out of the total (63).
Displayed on All Players home page.

=cut

sub count_player_picks {
    my ($self) = @_;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select player.id, count(*) from player
            join picks on player.id = picks.player
            group by player.id
            ;'
            );
            $sth->execute() or die $sth->errstr;
            my $picks_per_player = {};
            my $result = $sth->fetchall_arrayref;
            foreach my $row (@{$result}) {
                $picks_per_player->{$row->[0]} = $row->[1];
            }
            return $picks_per_player;
        }
    );
}

=heads2 count_player_picks_correct

Count up how many picks a player has made correct so far.
Displayed on All Players home page.

=cut

sub count_player_picks_correct {
    my $self = shift;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('                   
            select player_picks.player, count(*)
              from picks player_picks, picks perfect_picks, game game, team team
             where perfect_picks.pick   = player_picks.pick 
               and perfect_picks.game   = player_picks.game 
               and player_picks.game    = game.id
               and player_picks.pick    = team.id
               and perfect_picks.player = 1
          group by player_picks.player
          ;'
          );
          $sth->execute() or die $sth->errstr;
          my $picks_per_player = {};
          my $result = $sth->fetchall_arrayref;
          foreach my $row (@{$result}) {
              $picks_per_player->{$row->[0]} = $row->[1];
          }
          return $picks_per_player;
        }
    );
}

=heads2 count_final4_picks

Count up how many picks a player has made in the final 4 (3 total).
Displayed on Players home page.

=cut

sub count_final4_picks {
    my ($self, $player_id) = @_;
    my $storage = $self->schema->storage;
    return $storage->dbh_do(
        sub {
            my $self = shift;
            my $dbh  = shift;
            my $sth  = $dbh->prepare('
            select count(*) from player
            join picks on player.id = picks.player
            where picks.game > 60
            and player.id = ?
            ;'
            );
            $sth->execute($player_id) or die $sth->errstr;
            
            return $sth->fetchall_arrayref->[0]->[0];
        }
    );
}

=head1 NAME

Bracket::Model::DBIC - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<Bracket>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Bracket::Schema::DBIC>

=head1 AUTHOR

Mateu X Hunter

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
