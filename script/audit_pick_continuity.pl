#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Bracket::Schema;
use Bracket::Service::BracketValidator;
use Getopt::Long qw(GetOptions);

my %opt;
GetOptions(
    'config=s' => \$opt{config},
    'dsn=s'    => \$opt{dsn},
    'user=s'   => \$opt{user},
    'pass=s'   => \$opt{pass},
    'help'     => \$opt{help},
) or die usage();

if ($opt{help}) {
    print usage();
    exit 0;
}

my $config_path = $opt{config} || "$FindBin::Bin/../bracket_local.conf";
my ($cfg_dsn, $cfg_user, $cfg_pass) = read_db_from_config($config_path);

# Precedence: CLI flags > env vars > bracket_local.conf > hardcoded fallback.
my $dsn  = defined $opt{dsn}  ? $opt{dsn}  : ($ENV{BRACKET_DSN}         || $cfg_dsn  || 'dbi:mysql:database=bracket_2026;host=127.0.0.1;port=3306');
my $user = defined $opt{user} ? $opt{user} : ($ENV{BRACKET_DB_USER}     || $cfg_user || 'root');
my $pass = defined $opt{pass} ? $opt{pass} : (exists $ENV{BRACKET_DB_PASSWORD} ? $ENV{BRACKET_DB_PASSWORD} : (defined $cfg_pass ? $cfg_pass : ''));

my $schema = Bracket::Schema->connect($dsn, $user, $pass);
my $structure = Bracket::Service::BracketValidator->validate_graph_invariants($schema);
if (!$structure->{ok}) {
    print "ERROR: bracket structure is invalid\n";
    print " - $_\n" for @{$structure->{errors} || []};
    exit 2;
}

my @players = $schema->resultset('Player')->search({ active => 1 })->all;
my $issues = 0;

for my $player (@players) {
    my %picks = map { $_->game->id => $_->pick->id }
      $schema->resultset('Pick')->search({ player => $player->id })->all;

    for my $game_id (sort { $a <=> $b } grep { $_ >= 9 } keys %picks) {
        my @parents = map { $_->parent_game }
          $schema->resultset('GameGraph')->search({ game => $game_id })->all;
        next if !@parents;

        my @parent_winners = grep { defined $_ } map { $picks{$_} } @parents;
        next if @parent_winners < @parents;

        my %allowed = map { $_ => 1 } @parent_winners;
        if (!$allowed{$picks{$game_id}}) {
            $issues++;
            print join("\t",
                'player=' . $player->id,
                'game=' . $game_id,
                'pick=' . $picks{$game_id},
                'allowed=' . join(',', @parent_winners)
            ), "\n";
        }
    }
}

if (!$issues) {
    print "OK: no continuity issues found\n";
}

sub read_db_from_config {
    my ($path) = @_;
    return (undef, undef, undef) if !$path || !-f $path;

    open my $fh, '<', $path or return (undef, undef, undef);

    my ($dsn, $user, $pass);
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;
        next if $line eq '' || $line =~ /^#/;

        if (!defined $dsn && $line =~ /^dsn\s+(.+)$/i) {
            $dsn = $1;
            $dsn =~ s/\s+$//;
            next;
        }
        if (!defined $user && $line =~ /^user\s+(.+)$/i) {
            $user = $1;
            $user =~ s/\s+$//;
            next;
        }
        if (!defined $pass && $line =~ /^password\s+(.+)$/i) {
            $pass = $1;
            $pass =~ s/\s+$//;
            next;
        }
    }

    close $fh;
    return ($dsn, $user, $pass);
}

sub usage {
    return <<'USAGE';
Usage: audit_pick_continuity.pl [options]

Options:
  --config <path>   Path to bracket_local.conf (default: ../bracket_local.conf)
  --dsn <dsn>       DBI DSN override
  --user <user>     DB user override
  --pass <pass>     DB password override
  --help            Show this help

Resolution order:
  CLI flags > environment vars > config file > hardcoded fallback

Environment vars:
  BRACKET_DSN
  BRACKET_DB_USER
  BRACKET_DB_PASSWORD
USAGE
}
