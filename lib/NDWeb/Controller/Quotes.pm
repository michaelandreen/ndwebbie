package NDWeb::Controller::Quotes;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

NDWeb::Controller::Quotes - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;

	$c->assert_user_roles(qw//);

	my $search = $c->req->param('search');
	$search =~  s/^\s+|\s+$//g if $search;
	if ($search) {
		$c->stash(search => $search);
		my $dbh = $c->model;
		my $query = $dbh->prepare(q{
SELECT qid,quote FROM quotes
WHERE quote ILIKE '%' || $1 || '%' ORDER BY qid ASC
			});

		$query->execute($search);

		$c->stash(quotes => $query->fetchall_arrayref({}));
	}
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later

=cut

1;
