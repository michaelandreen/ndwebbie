package NDWeb::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

NDWeb::Controller::Root - Root Controller for NDWeb

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub index : Local Path Args(0) {
    my ( $self, $c ) = @_;

	$c->stash(abc => $c->req->base);
}

sub default : Path {
    my ( $self, $c ) = @_;
	$c->res->body( 'Page not found' );
    $c->response->status(404);
    
}

sub auto : Private {
	my ($self, $c) = @_;

	my $dbh = $c ->model;
	$c->stash(dbh => $dbh);

	$c->stash->{game}->{tick} = $dbh->selectrow_array('SELECT tick()',undef);

}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
