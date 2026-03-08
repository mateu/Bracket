#!/usr/bin/env perl

#BEGIN { $ENV{BRACKET_DEBUG} = 0 }
use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Bracket::Schema;
use Config::JFDI;
use Term::Prompt;

sub _parse_mysql_dsn {
    my ($dsn) = @_;
    return unless defined $dsn && $dsn =~ /^dbi:mysql:/i;

    my %parts;
    my $tail = $dsn;
    $tail =~ s/^dbi:mysql://i;

    for my $pair (split /;/, $tail) {
        next unless length $pair;
        my ($k, $v) = split /=/, $pair, 2;
        next unless defined $k;
        $parts{lc $k} = $v;
    }

    return \%parts;
}

sub _run_mysql_sql_file {
    my (%args) = @_;
    my $file = $args{file} or die "Missing SQL file path\n";
    my $dsn  = $args{dsn}  or die "Missing DSN\n";

    my $dsn_parts = _parse_mysql_dsn($dsn)
      or die "Not a MySQL DSN: $dsn\n";

    my @cmd = ('mysql');
    push @cmd, ('--host', $dsn_parts->{host})     if $dsn_parts->{host};
    push @cmd, ('--port', $dsn_parts->{port})     if $dsn_parts->{port};
    push @cmd, ('--socket', $dsn_parts->{mysql_socket}) if $dsn_parts->{mysql_socket};
    push @cmd, ('--user', $args{user})            if defined $args{user} && length $args{user};
    push @cmd, ("--password=$args{pass}")        if defined $args{pass} && length $args{pass};

    my $database = $dsn_parts->{database} || $dsn_parts->{dbname};
    push @cmd, $database if defined $database && length $database;

    open my $in, '<', $file or die "Unable to read SQL file $file: $!\n";
    open my $mysql, '|-', @cmd
      or die "Failed to start mysql client for $file: $!\n";

    while (my $line = <$in>) {
        print {$mysql} $line;
    }

    close $in;
    close $mysql or die "mysql failed while running $file\n";
}

sub _apply_mysql_post_deploy_sql {
    my (%args) = @_;
    my $dsn = $args{dsn} || '';
    return unless $dsn =~ /^dbi:mysql:/i;

    my @files = (
        "$Bin/../sql/populate-game-graph.sql",
        "$Bin/../sql/getter-functions.sql",
    );

    print "Applying MySQL post-deploy SQL scripts...\n";
    for my $file (@files) {
        if (!-f $file) {
            warn "Skipping missing SQL file: $file\n";
            next;
        }

        print "  - $file\n";
        _run_mysql_sql_file(
            dsn  => $args{dsn},
            user => $args{user},
            pass => $args{pass},
            file => $file,
        );
    }
}

my ($dsn, $user, $pass);
my $jfdi   = Config::JFDI->new(name => "Bracket");
my $config = $jfdi->get;

eval {
    if (!$dsn)
    {
        if (ref $config->{'Model::DBIC'}->{'connect_info'}) {
            $dsn  = $config->{'Model::DBIC'}->{'connect_info'}->{dsn};
            $user = $config->{'Model::DBIC'}->{'connect_info'}->{user};
            $pass = $config->{'Model::DBIC'}->{'connect_info'}->{password};

        }
        else {
            $dsn = $config->{'Model::DBIC'}->{'connect_info'};
        }
    }
};
if ($@) {
    die "Your DSN line in bracket.conf doesn't look like a valid DSN."
      . "  Add one, or pass it on the command line.";
}
die "No valid Data Source Name (DSN).\n" if !$dsn;
$dsn =~ s/__HOME__/$FindBin::Bin\/\.\./g;

my $schema = Bracket::Schema->connect($dsn, $user, $pass)
  or die "Failed to connect to database";

# Check if database is already deployed by
# examining if the table Team exists and has a record.
print "Team table count: ", $schema->resultset('Bracket::Schema::Result::Team')->count;
eval { $schema->resultset('Bracket::Schema::Result::Team')->count };
if ($@) {
    die "You already have a team table with data in your database: $@\n";
}

print "\nCreate an admin account..\n\n";
my %custom_values = (
    admin_first_name => prompt('x', 'First name:', '', ''),
    admin_last_name  => prompt('x', 'Last name:',  '', ''),
    admin_email      => prompt('x', 'E-Mail:',     '', ''),
    admin_password   => prompt('x', 'Password:',   '', ''),
);

print "\nDeploying schema to $dsn\n";
$schema->deploy;
print "Creating initial data and admin account.\n";
$schema->create_initial_data($config, \%custom_values);
_apply_mysql_post_deploy_sql(
    dsn  => $dsn,
    user => $user,
    pass => $pass,
);
print "Success!\n\nYou probably want to start your application, e.g:
    script/bracket_server.pl
and login with the admin account you just created.\n\n";
