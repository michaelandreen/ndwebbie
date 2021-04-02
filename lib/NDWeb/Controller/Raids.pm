package NDWeb::Controller::Raids;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use feature ':5.10';

use POSIX qw/floor pow/;
use NDWeb::Include;
use ND::Include;

=head1 NAME

NDWeb::Controller::Raids - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $launched = 0;
	my $query = $dbh->prepare(q{
		SELECT r.id,released_coords AS releasedcoords,tick
			,waves*COUNT(DISTINCT rt.id) AS waves,COUNT(rc.uid) AS claims
			,COUNT(nullif(rc.launched,false)) AS launched
			,COUNT(NULLIF(rc.uid > 0 OR rc.wave > r.waves,true)) AS blocked
		FROM raids r JOIN raid_targets rt ON r.id = rt.raid
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
		WHERE open AND not removed AND r.id 
			IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)
		GROUP BY r.id,released_coords,tick,waves});
	$query->execute($c->user->id);
	my @raids;
	while (my $raid = $query->fetchrow_hashref){
		$raid->{waves} -= $raid->{blocked};
		$raid->{claims} -= $raid->{blocked};
		delete $raid->{blocked};
		$launched += $raid->{launched};
		push @raids,$raid;
	}
	$c->stash(raids => \@raids);

	if ($c->check_user_roles(qw/raids_info/)){
		my $query = $dbh->prepare(q{
		SELECT r.id,open ,tick, open_tick, released_coords AS releasedcoords
			,waves*COUNT(DISTINCT rt.id) AS waves,COUNT(rc.uid) AS claims
			,COUNT(nullif(rc.launched,false)) AS launched
			,COUNT(NULLIF(uid > 0 OR rc.wave > r.waves,true)) AS blocked
		FROM raids r JOIN raid_targets rt ON r.id = rt.raid
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
		WHERE not removed AND (not open 
			OR r.id NOT IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?))
		GROUP BY r.id,open,tick,waves});
		$query->execute($c->user->id);
		my @raids;
		while (my $raid = $query->fetchrow_hashref){
			$raid->{waves} -= $raid->{blocked};
			$raid->{claims} -= $raid->{blocked};
			delete $raid->{blocked};
			$launched += $raid->{launched};
			push @raids,$raid;
		}
		$c->stash(closedraids => \@raids);


		$query = $dbh->prepare(q{
		SELECT r.id,tick,waves*COUNT(DISTINCT rt.id) AS waves
			,COUNT(rc.uid) AS claims
			,COUNT(nullif(rc.launched,false)) AS launched
			,COUNT(NULLIF(uid > 0 OR rc.wave > r.waves,true)) AS blocked
		FROM raids r JOIN raid_targets rt ON r.id = rt.raid
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
		WHERE removed
		GROUP BY r.id,tick,waves});
		$query->execute;
		my @oldraids;
		while (my $raid = $query->fetchrow_hashref){
			$raid->{waves} -= $raid->{blocked};
			$raid->{claims} -= $raid->{blocked};
			delete $raid->{blocked};
			$launched += $raid->{launched};
			push @oldraids,$raid;
		}
		$c->stash(removedraids => \@oldraids);
		$c->stash(launched => $launched);
	}

}

sub view : Local {
	my ( $self, $c, $raid ) = @_;
	my $dbh = $c->model;

	$c->forward('findRaid');
	$raid = $c->stash->{raid};

	my $planet;
	if ($c->user->planet){
		my $query = $dbh->prepare(q{SELECT value, score,x,y FROM current_planet_stats WHERE pid = ?});
		$planet = $dbh->selectrow_hashref($query,undef,$c->user->planet);
	}
	$c->stash(message => parseMarkup($raid->{message}));
	$c->stash(landingtick => $raid->{tick});
	my $targetquery = $dbh->prepare(q{SELECT r.id, pid AS planet, size, score, value
		, p.pid, p.x,p.y,p.z, race
		, p.value - p.size*200 -
			COALESCE(ps.metal+ps.crystal+ps.eonium,0)/150 -
			COALESCE(ds.total ,(SELECT
				COALESCE(avg(total),0) FROM
				current_development_scans)::int)*1500 AS fleetvalue
		,(metal+crystal+eonium)/100 AS resvalue, comment
		, hidden, light, medium, heavy, metal, crystal, eonium
		,metal_roids, crystal_roids, eonium_roids
		,amps, distorters, light_fac, medium_fac, heavy_fac
		,hulls, waves
		FROM current_planet_stats p
			JOIN raid_targets r USING (pid)
			LEFT OUTER JOIN current_planet_scans ps USING (pid)
			LEFT OUTER JOIN current_development_scans ds USING (pid)
		WHERE r.raid = $1
			AND NOT COALESCE(p.x = $2 AND p.y = $3,False)
		ORDER BY size DESC, value DESC, score DESC});
	$targetquery->execute($raid->{id},$planet->{x},$planet->{y});
	my @targets;
	while (my $target = $targetquery->fetchrow_hashref){
		if ($planet && $planet->{x}){
			#if ($planet->{x} == $target->{x}){
			#	$target->{style} = 'incluster';
			#}
			$target->{cap} = min(0.25,0.25 * pow($target->{value}/$planet->{value} , 0.5));
			$target->{scorebash} = 'bash' if ($target->{score}/$planet->{score} < 0.6);
			$target->{valuebash} = 'bash' if ($target->{value}/$planet->{value} < 0.4);
		}
		$target->{cap} //= 0.25;

		my $unitscans = $dbh->prepare(q{
SELECT DISTINCT ON (name) fid, name, tick, amount
FROM fleets
WHERE pid = ?
	AND mission = 'Full fleet'
GROUP BY fid,tick,name,amount
ORDER BY name,tick DESC
		});
		$unitscans->execute($target->{planet});
		my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
			WHERE fid = ? ORDER BY num
		});
		my @missions;
		my $tick = 0;
		while (my $mission = $unitscans->fetchrow_hashref){
			my @ships;
			last if $mission->{tick} <= $tick;
			$tick = $mission->{tick};
			$ships->execute($mission->{fid});
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
			$mission->{ships} = \@ships;
			push @missions,$mission;
		}
		$target->{missions} = \@missions;

		my @roids;
		my @claims;
		my $size = $target->{size};
		for (my $i = 1; $i <= $raid->{waves}; $i++){
			my $roids = floor($target->{cap}*$size);
			$size -= floor(0.25*$size);
			my $xp = 0;
			if ($planet && $planet->{score}){
				$xp = pa_xp($roids,$planet->{score},$planet->{value},$target->{score},$target->{value});
			}
			push @roids,{wave => $i, roids => $roids, xp => $xp};
			push @claims,{wave => $i}
		}
		$target->{roids} = \@roids;
		$target->{claims} = \@claims;

		my $num = pow(10,length($target->{score})-2);
		$target->{score} = "Hidden" unless $raid->{released_coords}; #ceil($target->{score}/$num)*$num;
		$num = pow(10,length($target->{value})-2);
		$target->{value} = "Hidden" unless $raid->{released_coords}; #ceil($target->{value}/$num)*$num;
		$num = pow(10,length($target->{size})-2);
		$target->{size} = floor($target->{size}/$num)*$num;
		$num = pow(10,length($target->{fleetvalue})-2);
		$target->{fleetvalue} = floor($target->{fleetvalue}/$num)*$num;
		if (defined $target->{resvalue}){
			$num = pow(10,length($target->{resvalue})-2);
			$target->{resvalue} = floor($target->{resvalue}/$num)*$num;
		}
		$target->{comment} = parseMarkup($target->{comment}) if ($target->{comment});
		$target->{hidden} = int($target->{hidden} / 100) if $target->{hidden};

		push @targets,$target;
	}
	#@targets = sort {$b->{roids}[0]{xp} <=> $a->{roids}[0]{xp} or $b->{size} <=> $a->{size}} @targets;

	$c->stash(targets => \@targets);
}

sub edit : Local {
	my ($self, $c, $raid, $order) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT id,tick,waves,message,released_coords,open,ftid,open_tick
		FROM raids WHERE id = ?
	});
	$raid = $dbh->selectrow_hashref($query,undef,$raid);

	$c->stash(raid => $raid);

	$c->stash(errors => $c->flash->{errors});

	my $groups = $dbh->prepare(q{
SELECT g.gid,g.groupname,raid
FROM groups g
	LEFT OUTER JOIN (SELECT gid,raid FROM raid_access WHERE raid = ?) AS ra USING (gid)
WHERE gid IN (SELECT gid FROM group_roles WHERE role = 'attack_menu')
		});
	$groups->execute($raid ? $raid->{id} : undef);

	my @addgroups;
	my @remgroups;
	while (my $group = $groups->fetchrow_hashref){
		if ($group->{raid}){
			push @remgroups,$group;
		}else{
			push @addgroups,$group;
		}
	}
	$c->stash(removegroups => \@remgroups);
	$c->stash(addgroups => \@addgroups);

	if ($order && $order =~ /^(score|size|value|xp)rank$/){
		$order .= " ASC";
	}elsif ($order && $order eq 'race'){
		$order .= ' ASC';
	}else {
		$order = 'p.x,p.y,p.z';
	}

	my $targetquery = $dbh->prepare(qq{SELECT r.id,coords(x,y,z),comment,size
		,score,value,race,planet_status,relationship,pid AS planet, s.scans
		,COALESCE(max(rc.wave),0) AS waves
		FROM raid_targets r
			JOIN current_planet_stats p USING (pid)
			LEFT OUTER JOIN ( SELECT pid, array_agg(s::text) AS scans
				FROM ( SELECT DISTINCT ON (pid,type) pid,scan_id,type, tick
					FROM scans
					WHERE tick > tick() - 24
					ORDER BY pid,type ,tick DESC
					) s
				GROUP BY pid
			) s USING (pid)
			LEFT OUTER JOIN raid_claims rc ON r.id = rc.target
		WHERE r.raid = ?
		GROUP BY r.id,x,y,z,comment,size,score,value,race
			,planet_status,relationship,comment,pid, s.scans
			,sizerank,scorerank,xprank,valuerank
		ORDER BY $order
		});
	my $claims =  $dbh->prepare(q{ SELECT username,launched FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ?});

	$targetquery->execute($raid->{id});
	my @targets;
	while (my $target = $targetquery->fetchrow_hashref){
		my @waves;
		if ($target->{waves} < $raid->{waves}){
			$target->{waves} = $raid->{waves}
		}
		for my $i (1 .. $target->{waves}){
			$claims->execute($target->{id},$i);
			my $claimers;
			if ($claims->rows != 0){
				my $owner = 0;
				my @claimers;
				while (my $claim = $claims->fetchrow_hashref){
					$claim->{username} .= '*' if ($claim->{launched});
					push @claimers,$claim->{username};
				}
				$claimers = join '/', @claimers;
			}
			push @waves,{wave => $i, claimers => $claimers};
		}
		$target->{waves} = \@waves;

		$target->{scans} = array_expand $target->{scans};
		push @targets,$target;
	}
	$c->stash(targets => \@targets);

	$c->forward('listAlliances');
}

sub postraidupdate : Local {
	my ($self, $c, $raid) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $tick = $c->req->param('tick');
	my $waves = $c->req->param('waves');
	my $open_tick = $c->req->param('open_tick') || undef;
	$dbh->do(q{UPDATE raids SET message = ?, tick = ?, waves = ?, open_tick = ? WHERE id = ?}
		,undef,html_escape $c->req->param('message')
		,$tick,$waves,$open_tick,$raid);

	$c->forward('log',[$raid, 'BC updated raid']);

	my $delgroups = $dbh->prepare(q{DELETE FROM raid_access WHERE raid = $1 AND gid = ANY($2)});
	my $addgroups = $dbh->prepare(q{INSERT INTO raid_access (raid,gid) VALUES($1,unnest($2::text[]))});

	if ($c->req->param('add_group')){
		my @groups = $c->req->param('add_group');
		warn "GROUPS!!!!: @groups";
		$addgroups->execute($raid,\@groups);
		$c->forward('log',[$raid, "BC added access to groups: @groups"]);
	}
	if ($c->req->param('remove_group')){
		my @groups = $c->req->param('remove_group');
		$delgroups->execute($raid,\@groups);
		$c->forward('log',[$raid, "BC removed access for groups: @groups"]);
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$raid));
}

sub postaddtargets : Local {
	my ($self, $c, $raid) = @_;
	my $dbh = $c->model;

	my $sizelimit = $c->req->param('sizelimit');
	$sizelimit = -1 unless $sizelimit;

	my $targets = $c->req->param('targets');
	my $addtarget = $dbh->prepare(q{INSERT INTO raid_targets(raid,pid) (
		SELECT ?, pid FROM current_planet_stats p
		WHERE x = ? AND y = ? AND COALESCE(z = ?,TRUE)
		AND p.size > ?
		)});
	my @errors;
	while ($targets =~ m/(\d+):(\d+)(?::(\d+))?/g){
		my ($x,$y,$z) = ($1, $2, $3);
		eval {
			$addtarget->execute($raid,$1,$2,$3,$sizelimit);
		};

		if ($@ =~ /duplicate key value violates unique constraint "raid_targets_raid_key"/){
			if ($z){
				push @errors, "Planet already exists: $x:$y:$z";
			}else{
				push @errors, "A planet from $x:$y already exists in the raid,"
					." either remove it or add the planets separately.";
			}
		}else {
			push @errors, $@;
		}
	}
	if ($c->req->param('alliance') =~ /^(\d+)$/ && $1 ne 'NewDawn'){
		my $addtarget = $dbh->prepare(q{INSERT INTO raid_targets(raid,pid) (
			SELECT ?,pid FROM current_planet_stats p WHERE aid= ? AND p.size > ?)
			});
		eval {
			$addtarget->execute($raid,$1,$sizelimit);
			$c->forward('log',[$raid,"BC adding alliance '$1' to raid"]);
		};
		if ($@ =~ /duplicate key value violates unique constraint "raid_targets_raid_key"/){
			push @errors, "A planet from this alliance has already been added to the raid,"
				." either remove it or add the planets separately.";
		}else {
			push @errors, $@;
		}
	}

	$c->flash(errors => \@errors) if @errors;
	$c->res->redirect($c->uri_for('edit',$raid));
}

sub posttargetupdates : Local {
	my ($self, $c, $raid) = @_;
	my $dbh = $c->model;

	my @errors;
	my $comment = $dbh->prepare(q{UPDATE raid_targets SET comment = ? WHERE id = ?});
	my $unclaim =  $dbh->prepare(q{DELETE FROM raid_claims WHERE target = ? AND wave = ?});
	my $block = $dbh->prepare(q{INSERT INTO raid_claims (target,uid,wave) VALUES(?,-2,?)});
	my $claim = $dbh->prepare(q{INSERT INTO raid_claims (target,uid,wave)
		VALUES($1,(SELECT uid FROM users WHERE username ILIKE $3),$2)
		});
	my $unblock =  $dbh->prepare(q{DELETE FROM raid_claims
		WHERE target = ? AND wave = ? AND uid = -2
		});
	my $remove = $dbh->prepare(q{DELETE FROM raid_targets WHERE raid = ? AND id = ?});

	for $_ ($c->req->param()){
		if (/^comment:(\d+)$/){
			$comment->execute(html_escape $c->req->param($_),$1);
		}elsif(/^unclaim:(\d+):(\d+)$/){
			$unclaim->execute($1,$2);
			$c->forward('log',[$raid,"BC unclaimed target $1 wave $2."]);
		}elsif(/^block:(\d+):(\d+)$/){
			$block->execute($1,$2);
			$c->forward('log',[$raid,"BC blocked target $1 wave $2."]);
		}elsif(/^claim:(\d+):(\d+)$/){
			my $target = $1;
			my $wave = $2;
			my @claims = split /[, ]+/, $c->req->param($_);
			for (@claims){
				eval {
					$claim->execute($target,$wave,$_);
				};
				if ($@ =~ /null value in column "uid"/){
					push @errors, "Could not find user: " . html_escape $_;
				}elsif ($@ =~ /more than one row returned by a subquery/){
					push @errors, "This matched several users, please refine: " . html_escape $_;
				}else {
					push @errors, $@;
				}
			}
			if(@claims){
				$unblock->execute($target,$wave);
				$c->forward('log',[$raid,"BC claimed target $1 wave $2 for @claims."]);
			}
		}elsif(/^remove:(\d+)$/){
			$remove->execute($raid,$1);
			$c->forward('log',[$raid,"BC removed target $1"]);
		}
	}

	$c->flash(errors => \@errors) if @errors;
	$c->res->redirect($c->uri_for('edit',$raid));
}

sub open : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET open = TRUE, removed = FALSE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC opened raid"]);
	$c->model->commit;

	$c->forward('/redirect');
}

sub close : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET open = FALSE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC closed raid"]);
	$c->model->commit;

	$c->forward('/redirect');
}

sub remove : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET open = FALSE, removed = TRUE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC removed raid"]);
	$c->model->commit;

	$c->forward('/redirect');
}

sub showcoords : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET released_coords = TRUE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC released coords"]);
	$c->model->commit;

	$c->forward('/redirect');
}

sub hidecoords : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET released_coords = FALSE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC hid coords"]);
	$c->model->commit;

	$c->forward('/redirect');
}

sub create : Local {
	my ($self, $c) = @_;
	$c->stash(waves => 3);
	my @time = gmtime;
	$c->stash(landingtick => $c->stash->{TICK} + 24 - $time[2] + 12);
}

sub postcreate : Local {
	my ($self, $c) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $query = $dbh->prepare(q{INSERT INTO raids (tick,waves,message) VALUES(?,?,?) RETURNING (id)});
	my $tick = $c->req->param('tick');
	my $waves = $c->req->param('waves');
	my $message = html_escape $c->req->param('message');
	$query->execute($tick,$waves,$message);
	my $raid = $query->fetchrow_array;
	$c->forward('log',[$raid,"Created raid landing at tick: ".$tick]);

	if ($c->req->param('gal') || $c->req->param('target')) {
		my @gals = $c->req->param('gal');
		my @targets = $c->req->param('target');

		my $addtarget = $dbh->prepare(q{INSERT INTO raid_targets(raid,pid) (
			SELECT $1,pid FROM current_planet_stats p WHERE (planet_status IN ('','Hostile')
				AND (relationship IS NULL OR relationship IN ('','Hostile')))
				AND (pid = ANY ($2) OR ( size > $4 AND (x,y) IN (
					SELECT x,y FROM current_planet_stats WHERE pid = ANY ($3)))
				)
			)
		});
		my $sizelimit = $c->req->param('sizelimit');
		$addtarget->execute($raid,\@targets,\@gals,$sizelimit);
		$c->forward('log',[$raid,"BC added planets (@targets) and the gals for (@gals)"]);
	}
	$dbh->do(q{INSERT INTO raid_access (raid,gid) VALUES(?,'M')}
		,undef,$raid);
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$raid));
}

sub targetlist : Local {
	my ($self, $c, $alliances, $order) = @_;
	my $dbh = $c->model;

	$c->stash(allies => $alliances);
	$alliances ||= '';
	my @alliances = split /,/, $alliances;

	$c->forward('listAlliances');

	if ($order && $order =~ /^(sizerank|valuerank|scorerank|xprank|nfvalue|nfvalue2)$/){
		$order = "$1";
	}else{
		$order = "nfvalue";
	}
	$order = "p.$order" if $order =~ /rank$/;

	my $query = $dbh->prepare(q{
SELECT p.pid AS id, coords(p.x,p.y,p.z),p.x,p.y,p.alliance, p.score, p.value, p.size, p.xp,nfvalue, nfvalue - sum(pa.value) AS nfvalue2, p.race
FROM current_planet_stats p
	JOIN (SELECT g.x,g.y, sum(p.value) AS nfvalue
		FROM galaxies g join current_planet_stats p on g.x = p.x AND g.y = p.y
		WHERE g.tick = (SELECT max(tick) from galaxies)
			AND (planet_status IN ('','Hostile')
				AND (relationship IS NULL OR relationship IN ('','Hostile')))
		GROUP BY g.x,g.y
	) g USING (x,y)
	JOIN current_planet_stats pa USING (x,y,aid)
WHERE p.x <> 200
	AND aid = ANY ($1)
	AND p.relationship IN ('','Hostile')
GROUP BY p.pid, p.x,p.y,p.z,p.alliance, p.score, p.value, p.size, p.xp, nfvalue,p.race
	,p.scorerank,p.valuerank,p.sizerank,p.xprank
ORDER BY
		} . $order);
	$query->execute(\@alliances);
	$c->stash(planets => $query->fetchall_arrayref({}) );
	$c->forward('create');
}

sub posttargetalliances : Local {
	my ($self, $c) = @_;

	$c->res->redirect($c->uri_for('targetlist',join ',',$c->req->param('alliances')));
}

sub targetcalc : Local {
	my ($self, $c, $target) = @_;
	my $dbh = $c->model;

	$c->stash(target => $dbh->selectrow_hashref(q{
SELECT pid,metal_roids, crystal_roids, eonium_roids, ds.total
FROM raids r
	JOIN raid_targets rt ON r.id = rt.raid
	LEFT OUTER JOIN current_planet_scans ps USING (pid)
	LEFT OUTER JOIN current_development_scans ds USING (pid)
WHERE rt.id = ? AND r.open AND not r.removed
	AND r.id IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)
		},undef,$target,$c->user->id));

	my $fleets = $dbh->prepare(q{
SELECT DISTINCT ON (name) name, tick, fid, race
	,COALESCE($2,score) AS score, COALESCE($2, value) AS value
FROM fleets LEFT OUTER JOIN current_planet_stats p USING (pid)
WHERE pid = $1 AND mission = 'Full fleet'
ORDER BY name ASC, tick DESC
		});

	for ('def','att'){
		if (/^def/){
			$fleets->execute($c->stash->{target}->{pid}, 0);
		}else{
			$fleets->execute($c->user->planet,undef);
		}
		$c->stash($_ => $fleets->fetchall_arrayref({}));
	}

	$c->forward('calcredir');
}

sub fleetcalc : Local {
	my ($self, $c, $fid) = @_;
	my $dbh = $c->model;

	$c->stash(target => $dbh->selectrow_hashref(q{
SELECT pid,metal_roids, crystal_roids, eonium_roids, ds.total
FROM launch_confirmations lc
	LEFT OUTER JOIN current_planet_scans ps USING (pid)
	LEFT OUTER JOIN current_development_scans ds USING (pid)
WHERE uid = $1 AND fid = $2
			},undef,$c->user->id,$fid));

	my $fleets = $dbh->prepare(q{
SELECT DISTINCT ON (name) name, tick, fid, race
	,score AS score, value AS value
FROM fleets LEFT OUTER JOIN current_planet_stats p USING (pid)
WHERE pid = $1 AND mission = 'Full fleet'
ORDER BY name ASC, tick DESC
		});

	$fleets->execute($c->stash->{target}->{pid});
	$c->stash(def => $fleets->fetchall_arrayref({}));

	$fleets = $dbh->prepare(q{
SELECT tick, fid, race ,score , value
FROM fleets f LEFT OUTER JOIN current_planet_stats p USING (pid)
WHERE fid = $1 AND pid = $2
		});
	$fleets->execute($fid, $c->user->planet);
	$c->stash(att => $fleets->fetchall_arrayref({}));

	$c->forward('calcredir');
}

sub calcredir : Private {
	my ($self, $c) = @_;
	my $dbh = $c->model;

	my @query = (
		"def_structures=".($c->stash->{target}->{total} // 0),
		"def_metal_asteroids=".($c->stash->{target}->{metal_roids} // 0),
		"def_crystal_asteroids=".($c->stash->{target}->{crystal_roids} // 0),
		"def_eonium_asteroids=".($c->stash->{target}->{eonium_roids} // 0),
	);

	my $ships = $dbh->prepare(q{
SELECT id, amount FROM fleet_ships fs JOIN ship_stats s USING (ship)
WHERE fid = $1
		});

	my %races = (Ter => 1, Cat => 2, Xan => 3, Zik => 4, Etd => 5);
	for ('def','att'){
		my $nrfleets = 0;
		my $tick = 0;
		for my $fleet (@{$c->stash->{$_}}){
			$ships->execute($fleet->{fid});
			next unless $tick < $fleet->{tick};
			$tick = $fleet->{tick};
			++$nrfleets;
			push @query, "${_}_planet_value_${nrfleets}=$fleet->{value}";
			push @query, "${_}_planet_score_${nrfleets}=$fleet->{score}";
			push @query, "${_}_${nrfleets}_race=$races{$fleet->{race}}";
			while (my $ship = $ships->fetchrow_hashref){
				push @query, "${_}_${nrfleets}_$ship->{id}=$ship->{amount}";
			}
		}
		push @query, "${_}_fleets=$nrfleets";
	}
	my $query = join '&', @query;
	$c->res->redirect("http://game.planetarion.com/bcalc.pl?$query");
}

sub retal : Local {
	my ($self, $c) = @_;
	my $dbh = $c->model;

	my $incs = $dbh->prepare(q{
SELECT coords(x,y,z),pid,race,size,score,value,alliance
	,array_agg(i.eta) AS eta,array_agg(amount) AS amount
	,array_agg(shiptype) AS type,array_agg(fleet) AS name
	,array_agg(c.landing_tick) AS landing
FROM calls c
	JOIN incomings i USING (call)
	JOIN current_planet_stats p USING (pid)
WHERE c.status <> 'Covered' AND c.landing_tick BETWEEN tick() AND tick() + 6
	AND c.landing_tick + GREATEST(i.eta,7) > tick() + 10
GROUP BY pid,race,x,y,z,size,score,value,alliance
ORDER BY size DESC
		});
	$incs->execute;
	$c->stash(planets => $incs->fetchall_arrayref({}));

}

sub postcreateretal : Local {
	my ($self, $c) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $tick = $c->req->param('tick');
	my $waves = $c->req->param('waves');
	my $message = html_escape $c->req->param('message');
	my $query = $dbh->prepare(q{INSERT INTO raids (tick,waves,message) VALUES(?,?,?) RETURNING (id)});
	$query->execute($tick, $waves, $message);
	my $raid = $query->fetchrow_array;
	$c->forward('log',[$raid,"Created retal raid landing at tick: ".$c->req->param('tick')]);

	if ($c->req->param('target')) {
		my @targets = $c->req->param('target');

		my $addtarget = $dbh->prepare(q{
INSERT INTO raid_targets(raid,pid,comment) (
	SELECT $1,pid,array_to_string(array_agg(
			fleet || ': eta=' || eta || ', amount=' || amount || ', type=' || shiptype
				|| ' landing=' || landing_tick || 'back=' || landing_tick + eta
		),E'\n')
	FROM calls c
		JOIN incomings i USING (call)
		JOIN current_planet_stats p USING (pid)
	WHERE c.status <> 'Covered' AND c.landing_tick BETWEEN tick() AND tick() + 6
		AND c.landing_tick + GREATEST(i.eta,7) > tick() + 10
		AND pid = ANY ($2)
	GROUP BY pid
	)
		});
		$addtarget->execute($raid,\@targets);
		$c->forward('log',[$raid,"BC added planets (@targets) to retal_raid"]);
	}
	$dbh->do(q{INSERT INTO raid_access (raid,gid) VALUES(?,'M')}
		,undef,$raid);
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$raid));
}


sub listAlliances : Private {
	my ($self, $c) = @_;
	my @alliances;
	my $query = $c->model->prepare(q{SELECT aid AS id,alliance AS name FROM alliances
		WHERE relationship IN ('','Hostile')
			AND alliance IN (SELECT alliance FROM planets)
		 ORDER BY LOWER(alliance)
		});
	$query->execute;
	push @alliances,{id => '', name => ''};
	while (my $ally = $query->fetchrow_hashref){
		push @alliances,$ally;
	}
	$c->stash(alliances => \@alliances);
}

sub log : Private {
	my ($self, $c, $raid, $message) = @_;
	my $dbh = $c->model;

	my $log = $dbh->prepare(q{INSERT INTO forum_posts (uid,ftid,message)
		VALUES($1,(SELECT ftid FROM raids WHERE id = $2),$3)
		});
	$log->execute($c->user->id,$raid,$message);
}

sub findRaid : Private {
	my ( $self, $c, $raid ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT id,tick,waves,message,released_coords
		FROM raids WHERE id = ? AND open AND not removed AND id IN
			(SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)
		});
	$raid = $dbh->selectrow_hashref($query,undef,$raid,$c->user->id);
	$c->stash(raid => $raid);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
