package Bracket::Model::DBIC;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'Bracket::Schema',
    connect_info => [
        'dbi:mysql:bracket_2010',
        'dbuser',
        'generic',
        
    ],
);

=head1 NAME

Bracket::Model::DBIC - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<Bracket>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Bracket::Schema::DBIC>

=head1 AUTHOR

Mateu X Hunter

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
