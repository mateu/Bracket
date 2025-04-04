package Bracket::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces( result_namespace => 'Result', );

# Created by DBIx::Class::Schema::Loader v0.05003 @ 2010-02-28 11:54:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9Mvnns/DJ5m0MpQNixu/qQ

# You can replace this text with custom content, and it will be preserved on regeneration

sub create_initial_data {
  my ( $schema, $config, $custom_values ) = @_;

  $custom_values ||= {
    admin_first_name => 'Admin',
    admin_last_name  => 'User',
    admin_email      => "admin\@localhost.org",
    admin_password   => 'admin',
  };

  my @players = $schema->populate(
    'Player',
    [
      [qw/ email password first_name last_name /],
      [ 'no-reply@huntana.com', 'unknown', 'Perfect', 'Player', ],
      [
        $custom_values->{admin_email},      $custom_values->{admin_password},
        $custom_values->{admin_first_name}, $custom_values->{admin_last_name},
      ],
    ]
  );

  my @roles =
    $schema->populate( 'Role', [ [qw/ role /], ['admin'], ['basic'] ] );

  # Set admin account up with admin role. admins are able to edit the
  # perfect bracket among other things.
  my @player_roles =
    $schema->populate( 'PlayerRole',
    [ [qw/role player/], [ $roles[0]->id, $players[1]->id ], ] );

  create_new_year_data($schema);
}

sub create_new_year_data {
  my ( $schema, ) = @_;

  # Regions
  # NOTE: Get the 1 vs 2 region matchup for the final 4 correct
  # 3 and 4 will automatically be matched up properly as a result
  my @regions = $schema->populate(
    'Region',
    [
      [qw/ id name /],
      [ 1, 'South' ],
      [ 2, 'West' ],
      [ 3, 'East' ],
      [ 4, 'Midwest' ],
    ]
  );

  # Teams
  my @teams = $schema->populate(
    'Team',
    [
      [qw/ id seed name region /],
      [ 1,  1,  'Auburn',           1 ],
      [ 2,  16, 'AL St/St Francis', 1 ],
      [ 3,  8,  'Louisville',       1 ],
      [ 4,  9,  'Creighton',        1 ],
      [ 5,  5,  'Michigan',         1 ],
      [ 6,  12, 'UC San Diego',     1 ],
      [ 7,  4,  'Texas A&M',        1 ],
      [ 8,  13, 'Yale',             1 ],
      [ 9,  6,  'Ole Miss',         1 ],
      [ 10, 11, 'SD St/UNC',        1 ],
      [ 11, 3,  'Iowa State',       1 ],
      [ 12, 14, 'Lipscomb',         1 ],
      [ 13, 7,  'Marquette',        1 ],
      [ 14, 10, 'New Mexico',       1 ],
      [ 15, 2,  'Michigan St',      1 ],
      [ 16, 15, 'Bryant',           1 ],

      [ 17, 1,  'Florida',      2 ],
      [ 18, 16, 'Norfolk St',   2 ],
      [ 19, 8,  'UConn',        2 ],
      [ 20, 9,  'Oklahoma',     2 ],
      [ 21, 5,  'Memphis',      2 ],
      [ 22, 12, 'Colorado St',  2 ],
      [ 23, 4,  'Maryland',     2 ],
      [ 24, 13, 'Grand Canyon', 2 ],
      [ 25, 6,  'Missouri',     2 ],
      [ 26, 11, 'Drake',        2 ],
      [ 27, 3,  'Texas Tech',   2 ],
      [ 28, 14, 'UNCW',         2 ],
      [ 29, 7,  "Kansas",       2 ],
      [ 30, 10, 'Arkansas',     2 ],
      [ 31, 2,  'St Johns',     2 ],
      [ 32, 15, 'Omaha',        2 ],

      [ 33, 1,  'Duke',           3 ],
      [ 34, 16, 'Am/Mt St Marys', 3 ],
      [ 35, 8,  'Mississippi St', 3 ],
      [ 36, 9,  'Baylor',         3 ],
      [ 37, 5,  'Oregon',         3 ],
      [ 38, 12, 'Liberty',        3 ],
      [ 39, 4,  'Arizona',        3 ],
      [ 40, 13, 'Akron',          3 ],
      [ 41, 6,  'BYU',            3 ],
      [ 42, 11, 'VCU',            3 ],
      [ 43, 3,  'Wisconsin',      3 ],
      [ 44, 14, 'Montana',        3 ],
      [ 45, 7,  'St Marys',       3 ],
      [ 46, 10, 'Vanderbilt',     3 ],
      [ 47, 2,  'Alabama',        3 ],
      [ 48, 15, 'Robert Morris',  3 ],

      [ 49, 1,  'Houston',          4 ],
      [ 50, 16, 'SIU Edwardsville', 4 ],
      [ 51, 8,  'Gonzaga',          4 ],
      [ 52, 9,  'Georgia',          4 ],
      [ 53, 5,  'Clemson',          4 ],
      [ 54, 12, 'McNeese',          4 ],
      [ 55, 4,  'Purdue',           4 ],
      [ 56, 13, 'High Point',       4 ],
      [ 57, 6,  'Illinois',         4 ],
      [ 58, 11, 'TX/Xavier',        4 ],
      [ 59, 3,  'Kentucky',         4 ],
      [ 60, 14, 'Troy',             4 ],
      [ 61, 7,  'UCLA',             4 ],
      [ 62, 10, 'Utah St',          4 ],
      [ 63, 2,  'Tennessee',        4 ],
      [ 64, 15, 'Wofford',          4 ],
    ]
  );

  # Games
  my @games = $schema->populate(
    'Game',
    [
      [qw/ id round /],
      [ 1,  1 ],
      [ 2,  1 ],
      [ 3,  1 ],
      [ 4,  1 ],
      [ 5,  1 ],
      [ 6,  1 ],
      [ 7,  1 ],
      [ 8,  1 ],
      [ 9,  2 ],
      [ 10, 2 ],
      [ 11, 2 ],
      [ 12, 2 ],
      [ 13, 3 ],
      [ 14, 3 ],
      [ 15, 4 ],
      [ 16, 1 ],
      [ 17, 1 ],
      [ 18, 1 ],
      [ 19, 1 ],
      [ 20, 1 ],
      [ 21, 1 ],
      [ 22, 1 ],
      [ 23, 1 ],
      [ 24, 2 ],
      [ 25, 2 ],
      [ 26, 2 ],
      [ 27, 2 ],
      [ 28, 3 ],
      [ 29, 3 ],
      [ 30, 4 ],
      [ 31, 1 ],
      [ 32, 1 ],
      [ 33, 1 ],
      [ 34, 1 ],
      [ 35, 1 ],
      [ 36, 1 ],
      [ 37, 1 ],
      [ 38, 1 ],
      [ 39, 2 ],
      [ 40, 2 ],
      [ 41, 2 ],
      [ 42, 2 ],
      [ 43, 3 ],
      [ 44, 3 ],
      [ 45, 4 ],
      [ 46, 1 ],
      [ 47, 1 ],
      [ 48, 1 ],
      [ 49, 1 ],
      [ 50, 1 ],
      [ 51, 1 ],
      [ 52, 1 ],
      [ 53, 1 ],
      [ 54, 2 ],
      [ 55, 2 ],
      [ 56, 2 ],
      [ 57, 2 ],
      [ 58, 3 ],
      [ 59, 3 ],
      [ 60, 4 ],
      [ 61, 5 ],
      [ 62, 5 ],
      [ 63, 6 ],
    ]
  );

  my @game_graph = $schema->populate(
    'GameGraph',
    [
      [qw/ game parent_game /],
      ( 9,  1 ),
      ( 9,  2 ),
      ( 10, 3 ),
      ( 10, 4 ),
      ( 11, 5 ),
      ( 11, 6 ),
      ( 12, 7 ),
      ( 12, 8 ),
      ( 13, 9 ),
      ( 13, 10 ),
      ( 14, 11 ),
      ( 14, 12 ),
      ( 15, 13 ),
      ( 15, 14 ),
      ( 24, 16 ),
      ( 24, 17 ),
      ( 25, 18 ),
      ( 25, 19 ),
      ( 26, 20 ),
      ( 26, 21 ),
      ( 27, 22 ),
      ( 27, 23 ),
      ( 28, 24 ),
      ( 28, 25 ),
      ( 29, 26 ),
      ( 29, 27 ),
      ( 30, 28 ),
      ( 30, 29 ),
      ( 39, 31 ),
      ( 39, 32 ),
      ( 40, 33 ),
      ( 40, 34 ),
      ( 41, 35 ),
      ( 41, 36 ),
      ( 42, 37 ),
      ( 42, 38 ),
      ( 43, 39 ),
      ( 43, 40 ),
      ( 44, 41 ),
      ( 44, 42 ),
      ( 45, 43 ),
      ( 45, 44 ),
      ( 54, 46 ),
      ( 54, 47 ),
      ( 55, 48 ),
      ( 55, 49 ),
      ( 56, 50 ),
      ( 56, 51 ),
      ( 57, 52 ),
      ( 57, 53 ),
      ( 58, 54 ),
      ( 58, 55 ),
      ( 59, 56 ),
      ( 59, 57 ),
      ( 60, 58 ),
      ( 60, 59 ),
      ( 61, 15 ),
      ( 61, 30 ),
      ( 62, 45 ),
      ( 62, 60 ),
      ( 63, 61 ),
      ( 63, 62 )
    ]
  );

  my @game_team_graph = $schema->populate(
    'GameTeamGraph',
    [
      [qw/ game team /],
      ( 1,  1 ),
      ( 1,  2 ),
      ( 2,  3 ),
      ( 2,  4 ),
      ( 3,  5 ),
      ( 3,  6 ),
      ( 4,  7 ),
      ( 4,  8 ),
      ( 5,  9 ),
      ( 5,  10 ),
      ( 6,  11 ),
      ( 6,  12 ),
      ( 7,  13 ),
      ( 7,  14 ),
      ( 8,  15 ),
      ( 8,  16 ),
      ( 16, 17 ),
      ( 16, 18 ),
      ( 17, 19 ),
      ( 17, 20 ),
      ( 18, 21 ),
      ( 18, 22 ),
      ( 19, 23 ),
      ( 19, 24 ),
      ( 20, 25 ),
      ( 20, 26 ),
      ( 21, 27 ),
      ( 21, 28 ),
      ( 22, 29 ),
      ( 22, 30 ),
      ( 23, 31 ),
      ( 23, 32 ),
      ( 31, 33 ),
      ( 31, 34 ),
      ( 32, 35 ),
      ( 32, 36 ),
      ( 33, 37 ),
      ( 33, 38 ),
      ( 34, 39 ),
      ( 34, 40 ),
      ( 35, 41 ),
      ( 35, 42 ),
      ( 36, 43 ),
      ( 36, 44 ),
      ( 37, 45 ),
      ( 37, 46 ),
      ( 38, 47 ),
      ( 38, 48 ),
      ( 46, 49 ),
      ( 46, 50 ),
      ( 47, 51 ),
      ( 47, 52 ),
      ( 48, 53 ),
      ( 48, 54 ),
      ( 49, 55 ),
      ( 49, 56 ),
      ( 50, 57 ),
      ( 50, 58 ),
      ( 51, 59 ),
      ( 51, 60 ),
      ( 52, 61 ),
      ( 52, 62 ),
      ( 53, 63 ),
      ( 53, 64 )
    ]
  );
}

1

__END__
# 2014 data
 my @teams = $schema->populate(
 'Team',
 [
 [qw/ id seed name region /],
 [ 1, 1, 'Florida', 1 ],
 [ 2, 16, 'Play-in', 1 ],
 [ 3, 8, 'Colorado', 1 ],
 [ 4, 9, 'Pittsburgh', 1 ],
 [ 5, 5, 'VCU', 1 ],
 [ 6, 12, 'SF Austin', 1 ],
 [ 7, 4, 'UCLA', 1 ],
 [ 8, 13, 'Tulsa', 1 ],
 [ 9, 6, 'Ohio St', 1 ],
 [ 10, 11, 'Dayton', 1 ],
 [ 11, 3, 'Syracuse.', 1 ],
 [ 12, 14, 'W. Michigan', 1 ],
 [ 13, 7, 'New Mexico', 1 ],
 [ 14, 10, 'Stanford', 1 ],
 [ 15, 2, 'Kansas', 1 ],
 [ 16, 15, 'Eastern KY', 1 ],

 [ 17, 1, 'Virginia', 2 ],
 [ 18, 16, 'Coastal Carolina', 2 ],
 [ 19, 8, 'Memphis', 2 ],
 [ 20, 9, 'Geo. Wash.', 2 ],
 [ 21, 5, 'Cincinnati', 2 ],
 [ 22, 12, 'Harvard', 2 ],
 [ 23, 4, 'Michigan St.', 2 ],
 [ 24, 13, 'Delaware', 2 ],
 [ 25, 6, 'North Carolina', 2 ],
 [ 26, 11, 'Providence', 2 ],
 [ 27, 3, 'Iowa St.', 2 ],
 [ 28, 14, 'N.C. Central', 2 ],
 [ 29, 7, 'Connecticut', 2 ],
 [ 30, 10, 'Saint Joseph', 2 ],
 [ 31, 2, 'Villanova', 2 ],
 [ 32, 15, 'UW Milwaukee', 2 ],

 [ 33, 1, 'Arizona', 3 ],
 [ 34, 16, 'Weber St.', 3 ],
 [ 35, 8, 'Gonzaga', 3 ],
 [ 36, 9, 'Oklahoma St.', 3 ],
 [ 37, 5, 'Oklahoma', 3 ],
 [ 38, 12, 'North Dakota St.', 3 ],
 [ 39, 4, 'San Diego St.', 3 ],
 [ 40, 13, 'New Mexico St.', 3 ],
 [ 41, 6, 'Baylor', 3 ],
 [ 42, 11, 'Nebraska', 3 ],
 [ 43, 3, 'Creighton', 3 ],
 [ 44, 14, 'UL Layfayette', 3 ],
 [ 45, 7, 'Oregon', 3 ],
 [ 46, 10, 'BYU', 3 ],
 [ 47, 2, 'Wisconsin', 3 ],
 [ 48, 15, 'American', 3 ],

 [ 49, 1, 'Witchita St', 4 ],
 [ 50, 16, 'Play-in', 4 ],
 [ 51, 8, 'Kentucky', 4 ],
 [ 52, 9, 'Kansas St.', 4 ],
 [ 53, 5, 'Saint Louis', 4 ],
 [ 54, 12, 'Play-in', 4 ],
 [ 55, 4, 'Louisiville', 4 ],
 [ 56, 13, 'Manhattan', 4 ],
 [ 57, 6, 'UMass', 4 ],
 [ 58, 11, 'Play-in', 4 ],
 [ 59, 3, 'Duke', 4 ],
 [ 60, 14, 'Mercer', 4 ],
 [ 61, 7, "Texas", 4 ],
 [ 62, 10, 'Arizona St.', 4 ],
 [ 63, 2, 'Michigan', 4 ],
 [ 64, 15, 'Wofford', 4 ],
 ]
 );
# 2010 data
 # Regions
 my @regions =
 $schema->populate('Region',
 [ [qw/ id name /], [ 1, 'Midwest' ], [ 2, 'West' ], [ 3, 'East' ], [ 4, 'South' ], ]);

 # Teams
 my @teams = $schema->populate(
 'Team',
 [
 [qw/ id seed name region /],
 [ 1, 1, 'Kansas', 1 ],
 [ 2, 16, 'Lehigh', 1 ],
 [ 3, 8, 'UNLV', 1 ],
 [ 4, 9, 'Northern Iowa', 1 ],
 [ 5, 5, 'Michigan St.', 1 ],
 [ 6, 12, 'New Mexico St.', 1 ],
 [ 7, 4, 'Maryland', 1 ],
 [ 8, 13, 'Houston', 1 ],
 [ 9, 6, 'Tennessee', 1 ],
 [ 10, 11, 'San Diego St.', 1 ],
 [ 11, 3, 'Georgetown', 1 ],
 [ 12, 14, 'Ohio', 1 ],
 [ 13, 7, 'Oklahoma St.', 1 ],
 [ 14, 10, 'Georgia Tech', 1 ],
 [ 15, 2, 'Ohio St.', 1 ],
 [ 16, 15, 'UCSB', 1 ],
 [ 17, 1, 'Syracuse', 2 ],
 [ 18, 16, 'Vermont', 2 ],
 [ 19, 8, 'Gonzaga', 2 ],
 [ 20, 9, 'Florida St.', 2 ],
 [ 21, 5, 'Butler', 2 ],
 [ 22, 12, 'UTEP', 2 ],
 [ 23, 4, 'Vanderbilt', 2 ],
 [ 24, 13, 'Murray St.', 2 ],
 [ 25, 6, 'Xavier', 2 ],
 [ 26, 11, 'Minnesota', 2 ],
 [ 27, 3, 'Pittsburgh', 2 ],
 [ 28, 14, 'Oakland', 2 ],
 [ 29, 7, 'BYU', 2 ],
 [ 30, 10, 'Florida', 2 ],
 [ 31, 2, 'Kansas St.', 2 ],
 [ 32, 15, 'North Texas', 2 ],
 [ 33, 1, 'Kentucky', 3 ],
 [ 34, 16, 'E. Tennessee St.', 3 ],
 [ 35, 8, 'Texas', 3 ],
 [ 36, 9, 'Wake Forest', 3 ],
 [ 37, 5, 'Temple', 3 ],
 [ 38, 12, 'Cornell', 3 ],
 [ 39, 4, 'Wisconsin', 3 ],
 [ 40, 13, 'Wofford', 3 ],
 [ 41, 6, 'Marquette', 3 ],
 [ 42, 11, 'Washington', 3 ],
 [ 43, 3, 'New Mexico', 3 ],
 [ 44, 14, 'Montana', 3 ],
 [ 45, 7, 'Clemson', 3 ],
 [ 46, 10, 'Missouri', 3 ],
 [ 47, 2, 'West Virginia', 3 ],
 [ 48, 15, 'Morgan St.', 3 ],
 [ 49, 1, 'Duke', 4 ],
 [ 50, 16, 'Ark-PB/Winthrop', 4 ],
 [ 51, 8, 'California', 4 ],
 [ 52, 9, 'Louisville', 4 ],
 [ 53, 5, 'Texas A&M', 4 ],
 [ 54, 12, 'Utah St.', 4 ],
 [ 55, 4, 'Purdue', 4 ],
 [ 56, 13, 'Siena', 4 ],
 [ 57, 6, 'Notre Dame', 4 ],
 [ 58, 11, 'Old Dominion', 4 ],
 [ 59, 3, 'Baylor', 4 ],
 [ 60, 14, 'Sam Houston St.', 4 ],
 [ 61, 7, 'Richmond', 4 ],
 [ 62, 10, "St. Mary's", 4 ],
 [ 63, 2, 'Villanova', 4 ],
 [ 64, 15, 'Robert Morris', 4 ],
 ]
 );

# 2011 Data
 my @regions = $schema->populate(
 'Region',
 [
 [qw/ id name /],
 [ 1, 'East' ],
 [ 2, 'West' ],
 [ 3, 'SouthWest' ],
 [ 4, 'SouthEast' ],
 ]
 );

 # Teams
 my @teams = $schema->populate(
 'Team',
 [
 [qw/ id seed name region /],
 [ 1, 1, 'Ohio St.', 1 ],
 [ 2, 16, 'UTSA/Bama St', 1 ],
 [ 3, 8, 'George Mason', 1 ],
 [ 4, 9, 'Villanova', 1 ],
 [ 5, 5, 'West Virginia', 1 ],
 [ 6, 12, 'UAB/Clemson', 1 ],
 [ 7, 4, 'Kentucky', 1 ],
 [ 8, 13, 'Princeton', 1 ],
 [ 9, 6, 'Xavier', 1 ],
 [ 10, 11, 'Marquette', 1 ],
 [ 11, 3, 'Syracuse', 1 ],
 [ 12, 14, 'Indiana St.', 1 ],
 [ 13, 7, 'Washington', 1 ],
 [ 14, 10, 'Georgia', 1 ],
 [ 15, 2, 'North Carolina', 1 ],
 [ 16, 15, 'Long Island', 1 ],
 [ 17, 1, 'Duke', 2 ],
 [ 18, 16, 'Hampton', 2 ],
 [ 19, 8, 'Michigan', 2 ],
 [ 20, 9, 'Tennessee', 2 ],
 [ 21, 5, 'Arizona', 2 ],
 [ 22, 12, 'Memphis', 2 ],
 [ 23, 4, 'Texas', 2 ],
 [ 24, 13, 'Oakland', 2 ],
 [ 25, 6, 'Cincinnati', 2 ],
 [ 26, 11, 'Missouri', 2 ],
 [ 27, 3, 'Connecticut', 2 ],
 [ 28, 14, 'Bucknell', 2 ],
 [ 29, 7, 'Temple', 2 ],
 [ 30, 10, 'Penn St.', 2 ],
 [ 31, 2, 'San Diego St.', 2 ],
 [ 32, 15, 'No. Colorado', 2 ],
 [ 33, 1, 'Kansas', 3 ],
 [ 34, 16, 'Boston U.', 3 ],
 [ 35, 8, 'UNLV', 3 ],
 [ 36, 9, 'Illinois', 3 ],
 [ 37, 5, 'Vanderbilt', 3 ],
 [ 38, 12, 'Richmond', 3 ],
 [ 39, 4, 'Louisville', 3 ],
 [ 40, 13, 'Morehead St.', 3 ],
 [ 41, 6, 'Georgetown', 3 ],
 [ 42, 11, 'USC/VCU', 3 ],
 [ 43, 3, 'Purdue', 3 ],
 [ 44, 14, "St. Peter's", 3 ],
 [ 45, 7, 'Texas A&M', 3 ],
 [ 46, 10, 'Florida St.', 3 ],
 [ 47, 2, 'Notre Dame', 3 ],
 [ 48, 15, 'Akron', 3 ],
 [ 49, 1, 'Pittsburgh', 4 ],
 [ 50, 16, 'NC-Ash/Ark-LR', 4 ],
 [ 51, 8, 'Butler', 4 ],
 [ 52, 9, 'Old Dominion', 4 ],
 [ 53, 5, 'Kansas St.', 4 ],
 [ 54, 12, 'Utah St.', 4 ],
 [ 55, 4, 'Wisconsin', 4 ],
 [ 56, 13, 'Belmont', 4 ],
 [ 57, 6, "St. John's", 4 ],
 [ 58, 11, 'Gonzaga', 4 ],
 [ 59, 3, 'BYU', 4 ],
 [ 60, 14, 'Wofford', 4 ],
 [ 61, 7, 'UCLA', 4 ],
 [ 62, 10, "Michigan St.", 4 ],
 [ 63, 2, 'Florida', 4 ],
 [ 64, 15, 'UC Santa Barb.', 4 ],
 ]
);

