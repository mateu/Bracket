use strict;
use warnings;
use Test::More;
use File::Spec;

my $script = File::Spec->catfile('script', 'deploy_bracket.pl');
ok(-f $script, 'deploy script exists');

open my $fh, '<', $script or die "Unable to read $script: $!";
my $src = do { local $/; <$fh> };
close $fh;

like(
    $src,
    qr{sub\s+_apply_mysql_post_deploy_sql\b}s,
    'defines _apply_mysql_post_deploy_sql helper'
);

like(
    $src,
    qr{\$Bin/\.\./sql/populate-game-graph\.sql}s,
    'includes populate-game-graph.sql in post-deploy list'
);

like(
    $src,
    qr{\$Bin/\.\./sql/getter-functions\.sql}s,
    'includes getter-functions.sql in post-deploy list'
);

like(
    $src,
    qr{\$schema->create_initial_data\(\$config,\s*\\%custom_values\);\s*_apply_mysql_post_deploy_sql\(}s,
    'runs MySQL post-deploy SQL after create_initial_data'
);

done_testing();
