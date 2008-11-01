package NDWeb::Controller::Raids;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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
	my $query = $dbh->prepare(q{SELECT r.id,released_coords AS releasedcoords,tick,waves*COUNT(DISTINCT rt.id) AS waves,
			COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched,COUNT(NULLIF(rc.uid > 0,true)) AS blocked
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
		my $query = $dbh->prepare(q{SELECT r.id,open ,tick,waves*COUNT(DISTINCT rt.id) AS waves,
			COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched ,COUNT(NULLIF(uid > 0,true)) AS blocked
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


		$query = $dbh->prepare(q{SELECT r.id,tick,waves*COUNT(DISTINCT rt.id) AS waves,
			COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched ,COUNT(NULLIF(uid > 0,true)) AS blocked
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

	$c->stash(comma => \&comma_value);

	$c->stash(raid => $raid->{id});
	my $planet;
	if ($c->user->planet){
		my $query = $dbh->prepare("SELECT value, score,x,y FROM current_planet_stats WHERE id = ?");
		$planet = $dbh->selectrow_hashref($query,undef,$c->user->planet);
	}
	$c->stash(message => parseMarkup($raid->{message}));
	$c->stash(landingtick => $raid->{tick});
	my $targetquery = $dbh->prepare(q{SELECT r.id, r.planet, size, score, value
		, p.x,p.y,p.z, race
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
			JOIN raid_targets r ON p.id = r.planet
			LEFT OUTER JOIN current_planet_scans ps ON p.id = ps.planet
			LEFT OUTER JOIN current_development_scans ds ON p.id = ds.planet
		WHERE r.raid = $1
			AND NOT COALESCE(p.x = $2 AND p.y = $3,False)
		ORDER BY size});
	$targetquery->execute($raid->{id},$planet->{x},$planet->{y});
	my @targets;
	while (my $target = $targetquery->fetchrow_hashref){
		if ($planet && $planet->{x}){
			if ($planet->{x} == $target->{x}){
				$target->{style} = 'incluster';
			}
			$target->{scorebash} = 'bash' if ($target->{score}/$planet->{score} < 0.4);
			$target->{valuebash} = 'bash' if ($target->{value}/$planet->{value} < 0.4);
			#next if ($target->{score}/$planet->{score} < 0.4) && ($target->{value}/$planet->{value} < 0.4);
		}

		my $unitscans = $dbh->prepare(q{ 
			SELECT DISTINCT ON (name) i.id,i.name, i.tick, i.amount 
			FROM fleets i
			WHERE  i.uid = -1
				AND i.sender = ?
				AND i.mission = 'Full fleet'
			GROUP BY i.id,i.tick,i.name,i.amount
			ORDER BY name,i.tick DESC
		});
		$unitscans->execute($target->{planet});
		my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
			WHERE id = ? ORDER BY num
		});
		my @missions;
		while (my $mission = $unitscans->fetchrow_hashref){
			my @ships;
			$ships->execute($mission->{id});
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
			my $roids = floor(0.25*$size);
			$size -= $roids;
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
		$target->{score} = "Hidden"; #ceil($target->{score}/$num)*$num;
		$num = pow(10,length($target->{value})-2);
		$target->{value} = "Hidden"; #ceil($target->{value}/$num)*$num;
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
	@targets = sort {$b->{roids}[0]{xp} <=> $a->{roids}[0]{xp} or $b->{size} <=> $a->{size}} @targets;

	$c->stash(targets => \@targets);
}

sub edit : Local {
	my ($self, $c, $raid, $order) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT id,tick,waves,message,released_coords,open,ftid
		FROM raids WHERE id = ?
	});
	$raid = $dbh->selectrow_hashref($query,undef,$raid);

	$c->stash(raid => $raid);

	$c->stash(errors => $c->flash->{errors});

	my $groups = $dbh->prepare(q{SELECT g.gid,g.groupname,raid FROM groups g LEFT OUTER JOIN (SELECT gid,raid FROM raid_access WHERE raid = ?) AS ra ON g.gid = ra.gid WHERE g.attack});
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
		$order .= 'p.x,p.y,p.z';
	}

	my $targetquery = $dbh->prepare(qq{SELECT r.id,coords(x,y,z),comment,size,score,value,race,planet_status AS planetstatus,relationship,comment,r.planet, s.scans
		FROM raid_targets r
			JOIN current_planet_stats p ON p.id = r.planet
			LEFT OUTER JOIN ( SELECT planet, array_accum(s::text) AS scans
				FROM ( SELECT DISTINCT ON (planet,type) planet,scan_id,type, tick
					FROM scans
					WHERE tick > tick() - 24
					ORDER BY planet,type ,tick DESC
					) s
				GROUP BY planet
			) s ON s.planet = r.planet
		WHERE r.raid = ?
		ORDER BY $order
		});
	my $claims =  $dbh->prepare(q{ SELECT username,launched FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ?});

	$targetquery->execute($raid->{id});
	my @targets;
	while (my $target = $targetquery->fetchrow_hashref){
		my @waves;
		for my $i (1 .. $raid->{waves}){
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
	$dbh->do(q{UPDATE raids SET message = ?, tick = ?, waves = ? WHERE id = ?}
		,undef,html_escape $c->req->param('message')
		,$c->req->param('tick'),$c->req->param('waves')
		,$raid);

	$c->forward('log',[$raid, 'BC updated raid']);

	my $groups = $dbh->prepare(q{SELECT gid,groupname FROM groups WHERE attack});
	my $delgroup = $dbh->prepare(q{DELETE FROM raid_access WHERE raid = ? AND gid = ?});
	my $addgroup = $dbh->prepare(q{INSERT INTO raid_access (raid,gid) VALUES(?,?)});

	$groups->execute();
	while (my $group = $groups->fetchrow_hashref){
		my $query;
		next unless defined $c->req->param($group->{gid});
		my $command = $c->req->param($group->{gid});
		if ( $command eq 'remove'){
			$query = $delgroup;
		}elsif($command eq 'add'){
			$query = $addgroup;
		}
		if ($query){
			$query->execute($raid,$group->{gid});
			$c->forward('log',[$raid, "BC '$command' access for $group->{gid} ($group->{groupname})"]);
		}
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
	my $addtarget = $dbh->prepare(qq{INSERT INTO raid_targets(raid,planet) (
		SELECT ?, id FROM current_planet_stats p
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
	if ($c->req->param('alliance') =~ /^(\d+)$/ && $1 != 1){
		my $addtarget = $dbh->prepare(qq{INSERT INTO raid_targets(raid,planet) (
			SELECT ?,id FROM current_planet_stats p WHERE alliance_id = ? AND p.size > ?)
			});
		eval {
			$addtarget->execute($raid,$1,$sizelimit);
			$c->forward('log',[$raid,"BC adding alliance $1 to raid"]);
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

	$c->res->redirect($c->req->referer);
}

sub close : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET open = FALSE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC closed raid"]);
	$c->model->commit;

	$c->res->redirect($c->req->referer);
}

sub remove : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET open = FALSE, removed = TRUE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC removed raid"]);
	$c->model->commit;

	$c->res->redirect($c->req->referer);
}

sub showcoords : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET released_coords = TRUE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC released coords"]);
	$c->model->commit;

	$c->res->redirect($c->req->referer);
}

sub hidecoords : Local {
	my ($self, $c, $raid) = @_;

	$c->model->begin_work;
	$c->model->do(q{UPDATE raids SET released_coords = FALSE WHERE id = ?}
		,undef,$raid);
	$c->forward('log',[$raid, "BC hid coords"]);
	$c->model->commit;

	$c->res->redirect($c->req->referer);
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
	$query->execute($c->req->param('tick'),$c->req->param('waves')
		,html_escape $c->req->param('message'));
	my $raid = $query->fetchrow_array;
	$c->forward('log',[$raid,"Created raid landing at tick: ".$c->req->param('tick')]);

	if ($c->req->param('gal') || $c->req->param('target')) {
		my @gals = $c->req->param('gal');
		my @targets = $c->req->param('target');

		my $addtarget = $dbh->prepare(q{INSERT INTO raid_targets(raid,planet) (
			SELECT $1,id FROM current_planet_stats p WHERE (planet_status IN ('','Hostile')
				AND (relationship IS NULL OR relationship IN ('','Hostile')))
				AND (id = ANY ($2) OR ( size > $4 AND (x,y) IN (
					SELECT x,y FROM current_planet_stats WHERE id = ANY ($3)))
				)
			)
		});
		$addtarget->execute($raid,\@targets,\@gals,$c->req->param('sizelimit'));
		$c->forward('log',[$raid,"BC added planets (@targets) and the gals for (@gals)"]);
	}
	$dbh->do(q{INSERT INTO raid_access (raid,gid) VALUES(?,2)}
		,undef,$raid);
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$raid));
}

sub targetlist : Local {
	my ($self, $c, $alliances, $order) = @_;
	my $dbh = $c->model;

	$c->stash(comma => \&comma_value);
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
SELECT p.id, coords(p.x,p.y,p.z),p.x,p.y,p.alliance, p.score, p.value, p.size, p.xp,nfvalue, nfvalue - sum(pa.value) AS nfvalue2, p.race
FROM current_planet_stats p
	JOIN (SELECT g.x,g.y, sum(p.value) AS nfvalue
		FROM galaxies g join current_planet_stats p on g.x = p.x AND g.y = p.y
		WHERE g.tick = (SELECT max(tick) from galaxies)
			AND (planet_status IN ('','Hostile')
				AND (relationship IS NULL OR relationship IN ('','Hostile')))
		GROUP BY g.x,g.y
	) g ON p.x = g.x AND p.y = g.y
	JOIN current_planet_stats pa ON pa.x = g.x AND pa.y = g.y
WHERE p.x <> 200
	AND p.alliance_id = ANY ($1)
	AND pa.alliance_id = ANY ($1)
	AND p.relationship IN ('','Hostile')
GROUP BY p.id, p.x,p.y,p.z,p.alliance, p.score, p.value, p.size, p.xp, nfvalue,p.race
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

sub listAlliances : Private {
	my ($self, $c) = @_;
	my @alliances;
	my $query = $c->model->prepare(q{SELECT id,name FROM alliances
		WHERE relationship IN ('','Hostile')
			AND id IN (SELECT alliance_id FROM planets)
		 ORDER BY LOWER(name)
		});
	$query->execute;
	push @alliances,{id => -1, name => ''};
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
