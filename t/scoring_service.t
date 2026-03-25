use strict;
use warnings;
use Test::More;

use lib qw(t/lib lib);
use BracketTestSchema;
use Bracket::Service::Scoring;

my $schema = BracketTestSchema->init_schema(populate => 1);
my $player_id = 2;

# Seed game metadata for deterministic scoring assertions.
$schema->resultset('Game')->find(1)->update({ lower_seed => 1 });
$schema->resultset('Game')->find(2)->update({ lower_seed => 1 });
$schema->resultset('Game')->find(3)->update({ lower_seed => 1 });
$schema->resultset('Game')->find(4)->update({ lower_seed => 1 });
$schema->resultset('Game')->find(9)->update({ lower_seed => 1 });
$schema->resultset('Game')->find(63)->update({ lower_seed => 1 });

# Force an eliminated team so unresolved picks can classify as out.
$schema->resultset('Team')->find(6)->update({ round_out => 1 });

# Perfect bracket picks (player 1) for some games only.
for my $row (
    [1, 1],
    [2, 3],
    [9, 1],
    [63, 63],
) {
    $schema->resultset('Pick')->update_or_create({
        player => 1,
        game   => $row->[0],
        pick   => $row->[1],
    });
}

# Player picks include: in, mismatch out, unresolved out, unresolved pending,
# plus scoring entries in rounds 2 and 6.
for my $row (
    [1, 1],   # in
    [2, 4],   # mismatch -> out
    [3, 6],   # unresolved + eliminated team -> out
    [4, 7],   # unresolved + alive team -> pending
    [9, 1],   # in (round 2)
    [63, 63], # in (championship multiplier 10)
) {
    $schema->resultset('Pick')->update_or_create({
        player => $player_id,
        game   => $row->[0],
        pick   => $row->[1],
    });
}

my $all_summary = Bracket::Service::Scoring->summarize_player($schema, $player_id);

is($all_summary->{class_for}->{1}, 'in', 'matching perfect pick is in');
is($all_summary->{class_for}->{2}, 'out', 'mismatched perfect pick is out');
is($all_summary->{class_for}->{3}, 'out', 'eliminated unresolved pick is out');
is($all_summary->{class_for}->{4}, 'pending', 'alive unresolved pick is pending');
is($all_summary->{class_for}->{9}, 'in', 'round 2 winner is in');
is($all_summary->{class_for}->{63}, 'in', 'championship winner is in');

# Points:
# game 1 (round1, seed1): (5 + 1*1) * 1  = 6
# game 9 (round2, seed1): (5 + 1*1) * 2  = 12
# game 63 (round6, seed2): (5 + 2*1) * 10 = 70
# total = 88
is($all_summary->{total_points}, 88, 'total points includes championship multiplier');
is($all_summary->{region_points}->{1}, 18, 'region 1 subtotal is tracked');
is($all_summary->{region_points}->{4}, 70, 'region 4 subtotal is tracked');

my $region_one_summary = Bracket::Service::Scoring->summarize_player(
    $schema,
    $player_id,
    region_id => 1,
);

is($region_one_summary->{total_points}, 18, 'region filter limits points to one region');
ok(!exists $region_one_summary->{class_for}->{63}, 'region filter excludes out-of-region game');
is($region_one_summary->{class_for}->{1}, 'in', 'region filter keeps in-region game status');

done_testing();
