package Bracket::Schema::Result::EquityCache;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Bracket::Schema::Result::EquityCache - Per-player default equity projection cache

=cut

__PACKAGE__->table("equity_cache");

=head1 ACCESSORS

=head2 player_id

  data_type: INT
  is_nullable: 0

=head2 cache_key

  data_type: VARCHAR
  size: 32
  is_nullable: 0
  default: 'default'

=head2 current_points

  data_type: INT
  is_nullable: 0
  default: 0

=head2 max_possible_points

  data_type: INT
  is_nullable: 0
  default: 0

=head2 projected_first_pct

  data_type: VARCHAR
  size: 16
  is_nullable: 0
  default: '0.00'

=head2 projected_podium_pct

  data_type: VARCHAR
  size: 16
  is_nullable: 0
  default: '0.00'

=head2 projected_score_avg

  data_type: VARCHAR
  size: 16
  is_nullable: 0
  default: '0.00'

=cut

__PACKAGE__->add_columns(
    "player_id",
    { data_type => "INT", is_nullable => 0 },
    "cache_key",
    { data_type => "VARCHAR", size => 32, is_nullable => 0, default_value => 'default' },
    "current_points",
    { data_type => "INT", is_nullable => 0, default_value => 0 },
    "max_possible_points",
    { data_type => "INT", is_nullable => 0, default_value => 0 },
    "projected_first_pct",
    { data_type => "VARCHAR", size => 16, is_nullable => 0, default_value => '0.00' },
    "projected_podium_pct",
    { data_type => "VARCHAR", size => 16, is_nullable => 0, default_value => '0.00' },
    "projected_score_avg",
    { data_type => "VARCHAR", size => 16, is_nullable => 0, default_value => '0.00' },
);

__PACKAGE__->set_primary_key("player_id", "cache_key");

1;
