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
                update player p, 
                (
                select  player_picks.player,
                        sum(g.round*(5 + g.lower_seed*t.seed)) as points
                  from picks player_picks, picks perfect_picks, game g, team t 
                 where perfect_picks.pick   = player_picks.pick 
                   and perfect_picks.game   = player_picks.game 
                   and player_picks.game    = g.id
                   and player_picks.pick    = t.id
                   and perfect_picks.player = 1
                   group by player_picks.player
                )  pp
                set p.points = pp.points
                where p.id = pp.player
                  and p.id <> 1
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
