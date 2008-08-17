package NDWeb::Controller::Stats;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Stats - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched NDWeb::Controller::Stats in Stats.');
}

sub galaxy : Local {
	my ( $self, $c, $x, $y, $z ) = @_;
	my $dbh = $c->model;

	$c->stash( comma => \&comma_value);

	my $query = $dbh->prepare(q{SELECT x,y,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day,
		planets,planets_gain,planets_gain_day
		,ticks_roiding, ticks_roided
	FROM galaxies g
		JOIN (SELECT x,y,count(CASE WHEN size_gain > 0 THEN 1 ELSE NULL END) AS ticks_roiding
			,count(CASE WHEN size_gain < 0 THEN 1 ELSE NULL END) AS ticks_roided
			FROM galaxies GROUP BY x,y) ga USING (x,y)
	WHERE tick = ( SELECT max(tick) AS max FROM galaxies)
		AND x = $1 AND y = $2
		});

	$query->execute($x,$y);
	$c->stash(g => $query->fetchrow_hashref );

	my $extra_columns = '';
	if ($c->check_user_roles(qw/stats_intel/)){
		$c->stash(intel => 1);
		$extra_columns = ",planet_status,hit_us, alliance,relationship,nick";
	}
	if ($c->check_user_roles(qw/stats_details/)){
		$c->stash( details => 1);
		$extra_columns .= q{
			,gov, p.value - p.size*200 -
			COALESCE(ps.metal+ps.crystal+ps.eonium,0)/150 -
			COALESCE(ss.total ,(SELECT COALESCE(avg(total),0)
				FROM structure_scans)::int)*1500 AS fleetvalue
			,(metal+crystal+eonium)/100 AS resvalue
		};
	}

	$query = $dbh->prepare(qq{SELECT DISTINCT ON (x,y,z,p.id)
		p.id,coords(x,y,z), ruler, p.planet,race,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day
		$extra_columns
		FROM current_planet_stats_full p
			LEFT OUTER JOIN planet_scans ps ON p.id = ps.planet
			LEFT OUTER JOIN structure_scans ss ON p.id = ss.planet
		WHERE x = ? AND y = ? AND COALESCE(z = ?,TRUE)
		ORDER BY x,y,z,p.id,ps.tick DESC, ps.id DESC, ss.tick DESC, ss.id DESC
		});

	$query->execute($x,$y,$z);
	$c->stash(planets => $query->fetchall_arrayref({}) );
}

sub planet : Local {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	my $p = $dbh->selectrow_hashref(q{SELECT id,x,y,z FROM current_planet_stats
		WHERE id = $1},undef,$id);

	$c->forward('galaxy',[$p->{x},$p->{y},$p->{z}]);
	$c->stash(p => $p);

	if ($c->check_user_roles(qw/stats_missions/)){
		my $query = $dbh->prepare(q{
			SELECT DISTINCT ON (i.tick,x,y,z,t.id,i.name,i.amount) i.id,i.mission, i.name, i.tick, i.eta AS eta
				, i.amount, coords(x,y,z) AS coords, t.id AS planet
			FROM ((
					SELECT * FROM fleets
					WHERE sender = $1 AND tick > tick() - 14
				) UNION (
					SELECT * FROM fleets WHERE sender = $1 AND mission = 'Full fleet'
					ORDER BY tick DESC LIMIT 5
				)
			) i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) t ON i.target = t.id
					AND t.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE  i.uid = -1
			ORDER BY i.tick,x,y,z,t.id,i.name,i.amount,i.eta
			});
		$query->execute($id);
		my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
			WHERE id = ? ORDER BY num
		});
		my @missions;
		while (my $mission = $query->fetchrow_hashref){
			my @ships;
			$ships->execute($mission->{id});
			if ($ships->rows != 0){
				while (my $ship = $ships->fetchrow_hashref){
					push @ships,$ship;
				}
				$mission->{ships} = \@ships;
			}
			push @missions,$mission;
		}
		$c->stash(outgoings => \@missions);

		$query = $dbh->prepare(q{
			SELECT DISTINCT ON (i.tick,x,y,z,s.id,i.name,i.amount) i.id,i.mission, i.name, i.tick,eta
						, i.amount, coords(x,y,z) AS coords, s.id AS planet
			FROM fleets i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) s ON i.sender = s.id
					AND s.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE  i.uid = -1
				AND i.target = ?
				AND i.tick > tick() - 3
			ORDER BY i.tick,x,y,z,s.id,i.name,i.amount,i.eta
		});
		$query->execute($id);
		my @incomings;
		while (my $mission = $query->fetchrow_hashref){
			my @ships;
			$ships->execute($mission->{id});
			if ($ships->rows != 0){
				while (my $ship = $ships->fetchrow_hashref){
					push @ships,$ship;
				}
				$mission->{ships} = \@ships;
			}
			push @incomings,$mission;
		}
		$c->stash(incomings => \@incomings);
	}

	if ($c->check_user_roles(qw/stats_scans/)){
		my $query = $dbh->prepare(q{SELECT type,scan_id, tick FROM scans
			WHERE planet = ? AND tick > tick() - 168
			ORDER BY tick,type DESC
		});
		$query->execute($id);
		$c->stash(scans => $query->fetchall_arrayref({}) );
	}

	if ($c->check_user_roles(qw/stats_planetdata/)){
		$c->stash(planetscan => $dbh->selectrow_hashref(q{SELECT *
			FROM current_planet_scans WHERE planet = $1},undef,$id));
		$c->stash(structurescan => $dbh->selectrow_hashref(q{SELECT *
			FROM current_structure_scans WHERE planet = $1},undef,$id));
		$c->stash(techscan => $dbh->selectrow_hashref(q{SELECT *
			FROM current_tech_scans WHERE planet = $1},undef,$id));
	}

	my $query = $dbh->prepare(q{SELECT value,value_gain AS gain,tick FROM planet_stats 
		WHERE id = ? AND tick > tick() - 24});
	$query->execute($id);
	$c->stash(values => $query->fetchall_arrayref({}) );

	$query = $dbh->prepare(q{SELECT x,y,z,tick FROM planet_stats
		WHERE id = ? ORDER BY tick ASC});
	$query->execute($id);
	my @coords;
	my $co = {x => 0, y => 0, z => 0};
	while (my $c2 = $query->fetchrow_hashref){
		if ($co->{x} != $c2->{x} || $co->{y} != $c2->{y} || $co->{z} != $c2->{z}){
			$co = $c2;
			push @coords,$co;
		}
	}
	$c->stash(oldcoords => \@coords);

}

sub find : Local {
	my ( $self, $c, $find ) = @_;
	my $dbh = $c->model;

	local $_ = $find || $c->req->param('coords');

	if (/(\d+)(?: |:)(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?/){
		my $planet = $dbh->selectrow_array(q{SELECT planetid($1,$2,$3,$4)}
			,undef,$1,$2,$3,$4);
		$c->res->redirect($c->uri_for('planet',$planet));
	}elsif (/(\d+)(?: |:)(\d+)/){
		$c->res->redirect($c->uri_for('galaxy',$1,$2));
	}

}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
