package NDWeb::Controller::CovOp;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

NDWeb::Controller::CovOp - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	$c->stash( where => q{AND MaxResHack > 130000
		ORDER BY minalert ASC,MaxResHack DESC});
	$c->forward('list');
}

sub distwhores : Local {
	my ( $self, $c ) = @_;
	$c->stash( where =>  qq{AND distorters > 0
		ORDER BY distorters DESC, minalert ASC});
	$c->forward('list');
}

sub marktarget : Local {
	my ( $self, $c, $target ) = @_;
	my $dbh = $c->model;
	my $update = $dbh->prepare(q{INSERT INTO covop_attacks (uid,id,tick) VALUES(?,?,tick())});
	eval{
		$update->execute($c->user->id,$target);
	};
	$c->forward('/redirect');
}

sub list : Private {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT id, coords, metal, crystal, eonium
		, covop_alert(seccents,structures,size,guards,gov,0) AS minalert
		, covop_alert(seccents,structures,size,guards,gov,50) AS maxalert
		, distorters,gov,pstick,dstick
		, MaxResHack,co.tick AS lastcovop
		FROM (SELECT p.id,coords(x,y,z),size, metal,crystal,eonium,guards
			,seccents,NULLIF(ds.total::integer,0) AS structures,distorters
			,max_bank_hack(metal,crystal,eonium,p.value
				,(SELECT value FROM current_planet_stats WHERE id = ?)) AS MaxResHack
			, planet_status, relationship,gov,ps.tick AS pstick, ds.tick AS dstick
			FROM current_planet_stats p
				LEFT OUTER JOIN current_planet_scans ps ON p.id = ps.planet
				LEFT OUTER JOIN current_development_scans ds ON p.id = ds.planet
			) AS foo
			LEFT OUTER JOIN (SELECT id,max(tick) AS tick FROM covop_attacks GROUP BY id) co USING (id)
		WHERE (metal IS NOT NULL OR seccents IS NOT NULL)
			AND (NOT planet_status IN ('Friendly','NAP'))
			AND  (relationship IS NULL OR NOT relationship IN ('Friendly','NAP'))
		} . $c->stash->{where});
	$query->execute($c->user->planet);

	my @targets;
	while (my $target = $query->fetchrow_hashref){
		push @targets,$target;
	}
	$c->stash(targets => \@targets);

	$c->stash(template => 'covop/index.tt2');
}
=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later

=cut

1;
