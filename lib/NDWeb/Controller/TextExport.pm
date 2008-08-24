package NDWeb::Controller::TextExport;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

NDWeb::Controller::TextExport - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub auto : Private {
	my ( $self, $c ) = @_;
	$c->stash(template => 'textexport/index.tt2');
}

sub alliance : Local {
	my ( $self, $c, $ally ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT coords(x,y,z), size, score, value, COALESCE(nick,'') AS nick
		FROM current_planet_stats
		WHERE alliance_id = $1
		ORDER BY x,y,z});
	$query->execute($ally);

	$c->stash(titles => $query->{NAME});
	$c->stash(values => $query->fetchall_arrayref);
}

sub end : ActionClass('RenderView') {
	my ( $self, $c ) = @_;
	$c->res->content_type('text/plain') if $c->stash->{template} =~ m{^textexport/};
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
