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
                  and player.id <> 1
                ;'
            );
            $sth->execute();
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
