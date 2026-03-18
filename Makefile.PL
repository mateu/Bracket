use FindBin;
use lib $FindBin::Bin;
use inc::Module::Install;

name 'Bracket';
all_from 'lib/Bracket.pm';
repository 'https://github.com/mateu/Bracket.git';
homepage 'https://github.com/mateu/Bracket';
bugtracker 'https://github.com/mateu/Bracket/issues';

requires(
    'Catalyst'                                     => '5.8000',
    'Catalyst::Action::RenderView'                 => 0,
    'Catalyst::Action::REST'                       => 0,
    'Catalyst::Authentication::Store::DBIx::Class' => 0,
    'Catalyst::Model::DBIC::Schema'                => '0.01',
    'Catalyst::Plugin::Authentication'             => '0.10005',
    'Catalyst::Plugin::ConfigLoader'               => 0,
    'Catalyst::Plugin::Session::State::Cookie'     => '0.11',
    'Catalyst::Plugin::Session::Store::DBIC'       => 0,
    'Catalyst::Plugin::Static::Simple'             => 0,
    'Catalyst::View::TT'                           => 0,
    'Config::General'                              => 0,
    'Config::JFDI'                                 => 0,
    'Crypt::Eksblowfish::Bcrypt'                   => 0,
    'DateTime',                                    => 0,
    'DBIx::Class'                                  => '0.08120',
    'DBIx::Class::EncodedColumn'                   => 0,
    'DBIx::Class::Schema'                          => 0,
    'Email::Sender',                               => 0,
    'Email::Simple',                               => 0,
    'Email::Valid',                                => 0,
    'HTML::FormHandler'                            => 0,
    'HTML::FormHandler::Model::DBIC'               => 0,
    'Moose'                                        => 0,
    'Net::SMTP',                                   => 0,
    'Perl6::Junction',                             => 0,
    'SQL::Translator'                              => '0.11005',
    'Term::Prompt'                                 => 0,
    'Time::HiRes'                                  => 0,
    'YAML'                                         => 0,
);

#catalyst;

# auto_install; # disabled for CPAN/release build flow
makemaker_args(
    NO_META   => 0,
    EXE_FILES => [ glob('script/*.pl') ],
    META_MERGE => {
        resources => {
            homepage   => 'https://github.com/mateu/Bracket',
            bugtracker => { web => 'https://github.com/mateu/Bracket/issues' },
            repository => {
                type => 'git',
                url  => 'https://github.com/mateu/Bracket.git',
                web  => 'https://github.com/mateu/Bracket',
            },
        },
    },
);
Makefile->write;
Meta->write;
