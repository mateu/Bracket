### use this module to generate a set of class files
# in a script
use DBIx::Class::Schema::Loader qw/ make_schema_at /;
make_schema_at(
    'Bracket::Schema',
    { debug => 0,
      dump_directory => './dump-lib',
    },
    [ 'dbi:mysql:dbname=bracket_2025', 'root', 'generic', ],
);

