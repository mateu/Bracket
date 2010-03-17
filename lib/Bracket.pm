package Bracket;
use Moose;

our $VERSION = '0.98';
use Catalyst::Runtime '5.80';

# Set flags and add plugins for the application
#
#   ConfigLoader: will load the configuration from a YAML file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

#  +CatalystX::SimpleLogin
use Catalyst qw/
  ConfigLoader
  Static::Simple
  Authentication
  Session
  Session::Store::DBIC
  Session::State::Cookie
  /;
extends 'Catalyst';

# Configure the application.
#
# Note that settings in bracket.yml (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
	authentication => {
		default_realm => 'members',
		realms        => {
			members => {
				credential => {
					class              => 'Password',
					password_field     => 'password',
					password_type      => 'self_check',
				},
				store => {
					class                     => 'DBIx::Class',
					user_model                => 'DBIC::Player',
					role_relation             => 'roles',
					role_field                => 'role',
#					use_userdata_from_session => 1,
				},
			},
		}
	}
);

# Session::Store
__PACKAGE__->config(
	'Plugin::Session' => {
		dbic_class => 'DBIC::Session',
		expires    => 604800,
	},
);

# Start the application
__PACKAGE__->setup;

=head1 NAME

Bracket - National College Basketball tournament bracket application

=head1 SYNOPSIS

    script/bracket_server.pl

=head1 DESCRIPTION

College Basketball Bracket application.

=head1 SEE ALSO unique => 1,

L<Bracket::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Mateu X. Hunter 2008-2010

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 COPYRIGHT

Mateu X. Hunter 2008

=cut

1;
