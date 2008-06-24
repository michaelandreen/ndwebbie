package NDWeb::Controller::Members;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

NDWeb::Controller::Members - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub points : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if ($order =~ /^((?:defense|attack|total|humor|scan|raid)_points)$/){
		$order = "$1 DESC";
	}else{
		$order = 'total_points DESC';
	}

	my $limit = 'LIMIT 10';
	$limit = '' if $c->check_user_roles(qw/members_points_nolimit/);

	my $query = $dbh->prepare(qq{SELECT username,defense_points,attack_points
		,scan_points,humor_points
		,(attack_points+defense_points+scan_points/20) as total_points
		, count(NULLIF(rc.launched,FALSE)) AS raid_points
		FROM users u LEFT OUTER JOIN raid_claims rc USING (uid)
		WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = 2)
		GROUP BY username,defense_points,attack_points,scan_points,humor_points,rank
		ORDER BY $order $limit});
	$query->execute;
	my @members;
	while (my $member = $query->fetchrow_hashref){
		push @members,$member;
	}
	$c->stash(members => \@members);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
