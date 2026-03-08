use strict;
use warnings;
use Test::More;

use lib qw(lib t/lib);
use BracketTestSchema;

my $schema = BracketTestSchema->init_schema(populate => 0);
ok($schema, 'init_schema returns a schema object');

ok(-e 't/var/bracket.yml', 'writes test config file t/var/bracket.yml');
ok(-e 't/var/bracket.db', 'creates sqlite db file t/var/bracket.db');

my $schema2 = BracketTestSchema->get_schema();
ok($schema2, 'get_schema returns a schema connection');

my $players_rs = $schema2->resultset('Player');
ok($players_rs, 'can access Player resultset from schema');

my $count = eval { $players_rs->count };
ok(! $@, 'resultset count query executes without error on fresh schema');

note("player count on fresh schema: " . (defined $count ? $count : 'undef'));

done_testing();
