use utf8;
package Bracket::Schema::Result::GameGraph;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Bracket::Schema::Result::GameGraph

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<game_graph>

=cut

__PACKAGE__->table("game_graph");

=head1 ACCESSORS

=head2 game

  data_type: 'integer'
  is_nullable: 1

=head2 parent_game

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "game",
  { data_type => "integer", is_nullable => 1 },
  "parent_game",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2025-03-21 15:52:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XCQ2KyHdrJAra0UKiMFZyA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
