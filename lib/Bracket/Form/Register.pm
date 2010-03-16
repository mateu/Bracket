package Bracket::Form::Register;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Model::DBIC';
with 'HTML::FormHandler::Render::Table';

has '+item_class' => ( default => 'Player' );

has_field 'first_name' => ( type => 'Text', required => 1 );
has_field 'last_name'  => ( type => 'Text' );
has_field 'email'      => (
	type   => 'Email',
	required => 1,
	unique => 1,
);
has_field 'password'         => ( type => 'Password', required => 1 );
has_field 'password_confirm' => ( type => 'PasswordConf' );
has_field 'submit' => ( type => 'Submit', value => 'Register' );

has '+unique_messages' =>
  ( default => sub { { player_email => 'Email address already registered' } } );


no HTML::FormHandler::Moose;
__PACKAGE__->meta->make_immutable;

1
