package NDWeb::Controller::Stats;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;
use HTML::TagCloud;

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

	my $query = $dbh->prepare(q{
SELECT x,y
	,size, size_gain, size_gain_day
	,score,score_gain,score_gain_day
	,value,value_gain,value_gain_day
	,xp,xp_gain,xp_gain_day
	,sizerank,sizerank_gain,sizerank_gain_day
	,scorerank,scorerank_gain,scorerank_gain_day
	,valuerank,valuerank_gain,valuerank_gain_day
	,xprank,xprank_gain,xprank_gain_day
	,planets,planets_gain,planets_gain_day
	,ticks_roiding, ticks_roided
	,raid.tick AS last_raid, raid
FROM galaxies g
	JOIN (SELECT x,y,count(CASE WHEN size_gain > 0 THEN 1 ELSE NULL END) AS ticks_roiding
			,count(CASE WHEN size_gain < 0 THEN 1 ELSE NULL END) AS ticks_roided
		FROM galaxies GROUP BY x,y) ga USING (x,y)
	LEFT OUTER JOIN (
		SELECT DISTINCT ON (x,y) x,y,raid, tick
		FROM (
			SELECT raid,p.tick,x,y,count(*), sum(size) AS size
			FROM raids r
				JOIN raid_targets rt ON r.id = rt.raid
				JOIN planet_stats p USING (pid)
			WHERE x = $1 and y = $2 AND p.tick = r.tick-12
			GROUP BY raid,p.tick,x,y
			) AS a
			JOIN galaxies g USING (tick,x,y)
		WHERE a.count::float / NULLIF(g.planets,0) >= 0.5
		ORDER BY x,y,tick
	) AS raid USING (x,y)

WHERE g.tick = ( SELECT max(tick) AS max FROM galaxies)
	AND x = $1 AND y = $2;
		});

	$query->execute($x,$y);
	my $g = $query->fetchrow_hashref;
	$c->detach('/default') unless $g;
	$c->stash(g => $g);


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
			COALESCE(ds.total ,(SELECT COALESCE(avg(total),0)
				FROM current_development_scans)::int)*1500 AS fleetvalue
			,(metal+crystal+eonium)/100 AS resvalue
		};
	}

	$query = $dbh->prepare(qq{SELECT DISTINCT ON (x,y,z,pid)
		pid AS id,coords(x,y,z), ruler, p.planet,race,
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
			LEFT OUTER JOIN planet_scans ps USING (pid)
			LEFT OUTER JOIN current_development_scans ds USING (pid)
		WHERE x = ? AND y = ? AND COALESCE(z = ?,TRUE)
		ORDER BY x,y,z,pid,ps.tick DESC, ps.id DESC, ds.tick DESC, ds.id DESC
		});

	$query->execute($x,$y,$z);
	$c->stash(planets => $query->fetchall_arrayref({}) );

	$query = $dbh->prepare(q{
WITH p AS (
	SELECT x,y FROM galaxies
	WHERE tick = tick() AND (x <= $1 AND y < $2 OR x < $1)
	ORDER BY x DESC, y DESC LIMIT 1
), n AS (
	SELECT x,y FROM galaxies
	WHERE tick = tick() AND (x >= $1 AND y > $2 OR x > $1)
	ORDER BY x ASC, y ASC LIMIT 1
)
TABLE p UNION TABLE n
		});
	$query->execute($x,$y);
	$c->stash(browse => $query->fetchall_arrayref({}) );
}

sub planet : Local {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	my $p = $dbh->selectrow_hashref(q{SELECT pid AS id,x,y,z FROM current_planet_stats
		WHERE pid = $1},undef,$id);

	$c->detach('/default') unless $p;

	$c->forward('galaxy',[$p->{x},$p->{y},$p->{z}]);
	$c->stash(p => $p);

	if ($c->check_user_roles(qw/stats_missions/)){
		my $query = $dbh->prepare(q{
(
	SELECT DISTINCT ON (mission,name) fid,mission,name,tick, NULL AS eta
		,amount, NULL AS coords, pid AS planet, NULL AS back
	FROM fleets f
	WHERE pid = $1 AND tick <= tick() AND (
			fid IN (SELECT fid FROM fleet_scans)
		) AND (
			mission = 'Full fleet'
			OR tick >= tick() - 12
		)
	ORDER BY mission,name,tick DESC
) UNION (
	SELECT DISTINCT ON (tick,x,y,z,mission,name,amount)
		NULL as fid, i.mission, i.name, i.tick,eta
		, i.amount, coords(x,y,z), pid AS planet, back
	FROM intel i
	LEFT OUTER JOIN current_planet_stats t ON i.target = pid
	WHERE uid = -1 AND i.sender = $1 AND i.tick > tick() - 14 AND i.tick < tick() + 14
	ORDER BY i.tick,x,y,z,mission,name,amount,back
)
		});
		$query->execute($id);
		my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
			WHERE fid = ? ORDER BY num
		});
		my @missions;
		while (my $mission = $query->fetchrow_hashref){
			my @ships;
			if ($mission->{fid}){
				$ships->execute($mission->{fid});
				while (my $ship = $ships->fetchrow_hashref){
					push @ships,$ship;
				}
				push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
				$mission->{ships} = \@ships;
			}
			push @missions,$mission;
		}
		$c->stash(outgoings => \@missions);

		$query = $dbh->prepare(q{
			SELECT DISTINCT ON (i.tick,x,y,z,pid,i.name,i.mission,i.amount) i.id,i.mission, i.name, i.tick,eta
						, i.amount, coords(x,y,z) AS coords, pid AS planet
			FROM intel i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) s ON i.sender = pid
					AND s.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE  i.uid = -1
				AND i.target = ?
				AND i.tick > tick() - 3
			ORDER BY i.tick,x,y,z,pid,i.name,i.mission,i.amount,i.eta
		});
		$query->execute($id);
		my @incomings;
		while (my $mission = $query->fetchrow_hashref){
			push @incomings,$mission;
		}
		$c->stash(incomings => \@incomings);
	}

	if ($c->check_user_roles(qw/stats_scans/)){
		my $query = $dbh->prepare(q{SELECT type,scan_id, tick FROM scans
			WHERE pid = ? AND tick > tick() - 168
			ORDER BY tick,type DESC
		});
		$query->execute($id);
		$c->stash(scans => $query->fetchall_arrayref({}) );
	}

	if ($c->check_user_roles(qw/stats_planetdata/)){
		$c->stash(planetscan => $dbh->selectrow_hashref(q{SELECT *
			FROM current_planet_scans WHERE pid = $1},undef,$id));
		$c->stash(devscan => $dbh->selectrow_hashref(q{SELECT *
			FROM current_development_scans WHERE pid = $1},undef,$id));
	}

	my $query = $dbh->prepare(q{SELECT value,value_gain AS gain,tick FROM planet_stats
		WHERE pid = ? AND tick > tick() - 24});
	$query->execute($id);
	$c->stash(values => $query->fetchall_arrayref({}) );

	$query = $dbh->prepare(q{SELECT x,y,z,tick FROM planet_stats
		WHERE pid = ? ORDER BY tick ASC});
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
	$c->stash(searchterm => $_);

	if (/(\d+)(?: |:)(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?/){
		my $planet = $dbh->selectrow_array(q{SELECT planetid($1,$2,$3,$4)}
			,undef,$1,$2,$3,$4);
		$c->res->redirect($c->uri_for('planet',$planet));
	}elsif (/(\d+)(?: |:)(\d+)/){
		$c->res->redirect($c->uri_for('galaxy',$1,$2));
	}elsif($c->check_user_roles(qw/stats_find_nick/)) {
		my $query = $dbh->prepare(q{SELECT pid AS id,coords(x,y,z),nick
			FROM current_planet_stats p
			WHERE nick ilike $1
		});
		$query->execute($_);
		my $planets = $query->fetchall_arrayref({});
		if (@{$planets} == 1){
			$c->res->redirect($c->uri_for('planet',$planets->[0]->{id}));
		}else{
			$c->stash(planets => $planets);
		}
	}
}

sub tags : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my @tags = $c->req->param('tags');
	$c->stash(tags => \@tags);
	my $query = $dbh->prepare(q{
SELECT tag, count(*)
FROM planet_tags pt
WHERE tag <> ALL($1)
	AND ($3 OR uid = $2)
GROUP BY tag
		});
	$query->execute(\@tags, $c->user->id, $c->check_user_roles('stats_tags_all') // 0);
	my $cloud = HTML::TagCloud->new;
	while (my $tag = $query->fetchrow_hashref){
		my @t = @tags;
		push @t, $tag->{tag};
		my %param = (tags => \@t);
		$cloud->add($tag->{tag}, $c->uri_for('tags',\%param), $tag->{count});
	}
	$c->stash(cloud => $cloud->html);
	$c->stash(css => $cloud->css);

	$query = $dbh->prepare(q{
WITH p AS (SELECT pid, coords(x,y,z) FROM current_planet_stats
), t AS (SELECT pid,tag,bool_or(uid = $2) AS own,max(time) AS time
	FROM planet_tags
	WHERE ($3 OR uid = $2)
	GROUP BY pid,tag
	ORDER BY time DESC
), tags AS (SELECT pid, array_agg(tag) AS tags
	FROM t GROUP BY pid
)
SELECT p.*k,array_to_string(tags,', ') AS tags FROM p JOIN tags USING (pid) WHERE tags @> $1;
		});
	$query->execute(\@tags, $c->user->id, $c->check_user_roles('stats_tags_all') // 0);
	$c->stash(planets => $query->fetchall_arrayref({}));
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
