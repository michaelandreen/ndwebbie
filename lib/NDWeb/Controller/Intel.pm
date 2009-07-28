package NDWeb::Controller::Intel;

use strict;
use warnings;
use feature ':5.10';
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Intel - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path : Args(0) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $ticks = $c->req->param('ticks') || 48;
	$c->stash(showticks => $ticks);

	my $query = $dbh->prepare(intelquery q{
			o.alliance AS oalliance ,coords(o.x,o.y,o.z) AS ocoords, i.sender
			,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords, i.target
		},q{not ingal
			AND ((COALESCE( t.alliance != o.alliance,TRUE) AND (i.mission = 'Defend' OR i.mission = 'AllyDef' ))
				OR ( t.alliance = o.alliance AND i.mission = 'Attack'))
			AND i.tick > (tick() - $1)
		});
	$query->execute($ticks);
	$c->stash(intel => $query->fetchall_arrayref({}) );

	if (defined $c->req->param('coords')){
		my $coords = $c->req->param('coords');
		my @coords;
		while ($coords =~ m/(\d+:\d+:\d+)/g){
			push @coords,$1;
		}
		my $planets = $dbh->prepare(q{SELECT pid AS id,coords(x,y,z), alliance, nick
			FROM current_planet_stats p
			WHERE coords(x,y,z) = ANY($1)
			ORDER BY alliance, p.x, p.y, p.z
		});
		$planets->execute(\@coords);
		$c->stash(coordslist => $planets->fetchall_arrayref({}) );
	}
}

sub planet : Local {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	$c->forward('findPlanet');
	my $p = $c->stash->{p};

	$c->stash(checkcoords => "$p->{x}:$p->{y}:$p->{z}");
	my $ticks = $c->req->param('ticks') || 48;
	$c->stash(showticks => $ticks);

	my $query = $dbh->prepare(q{SELECT pid AS id,coords(x,y,z),alliance,nick,channel
		FROM current_planet_stats WHERE channel = $1
		ORDER BY alliance,x,y,z
		});
	$query->execute($p->{channel});
	$c->stash(channelusers => $query->fetchall_arrayref({}) );

	$c->forward('/listAlliances');
	$c->forward('/forum/findPosts',[$p->{ftid}]);

	$c->stash(govs => ["","Feu", "Dic", "Dem","Uni"]);
	$c->stash(planetstatus => ["","Friendly", "NAP", "Hostile"]);

	$query = $dbh->prepare(intelquery q{i.sender
			,o.alliance AS oalliance,coords(o.x,o.y,o.z) AS ocoords
		},q{i.target = $1 AND i.tick > (tick() - $2)});
	$query->execute($id,$ticks);
	$c->stash(incoming => $query->fetchall_arrayref({}) );

	$query = $dbh->prepare(intelquery q{i.target
			,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords
		},q{i.sender = $1 AND i.tick > (tick() - $2)});
	$query->execute($id,$ticks);
	$c->stash(outgoing => $query->fetchall_arrayref({}) );

}

sub channels : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if ($order ~~ /(alliance)/){
		$order = "lower($1) ASC";
	}elsif ($order ~~ /(coords)/){
		$order = "x,y,z";
	}else{
		$order = 'channel';
	}

	my $query = $dbh->prepare(q{
SELECT pid AS id,coords(x,y,z),nick,channel,alliance FROM current_planet_stats
WHERE channel <> '' and channel IS NOT NULL
ORDER BY } . $order
	);
	$query->execute;
	$c->stash(planets => $query->fetchall_arrayref({}) );
}

sub postplanetcomment : Local {
	my ($self, $c, $p) = @_;

	$c->forward('findPlanet');
	$p = $c->stash->{p};

	$c->forward('/forum/insertPost',[$p->{ftid}]);
	$c->res->redirect($c->uri_for('planet',$p->{id}));
}

sub postplanetupdate : Local {
	my ($self, $c, $p) = @_;
	my $dbh = $c->model;

	$c->forward('findPlanet');
	$p = $c->stash->{p};

	$dbh->begin_work;
	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message)
		VALUES($2,$1,$3)
		});
	if ($c->req->param('cnick')){
		my $value = html_escape $c->req->param('nick');
		$dbh->do(q{UPDATE planets SET nick = ? WHERE pid =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set nick to: $value");
	}
	if ($c->req->param('cchannel')){
		my $value = html_escape $c->req->param('channel');
		$dbh->do(q{UPDATE planets SET channel = ? WHERE pid =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set channel to: $value");
	}
	if ($c->req->param('cstatus')){
		my $value = $c->req->param('status');
		$dbh->do(q{UPDATE planets SET planet_status = ? WHERE pid =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set planet_status to: $value");
	}
	if ($c->req->param('cgov')){
		my $value = $c->req->param('gov');
		$dbh->do(q{UPDATE planets SET gov = ? WHERE pid =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set gov to: $value");
	}
	if ($c->req->param('calliance')){
		my $value = $c->req->param('alliance');
		$dbh->do(q{UPDATE planets SET alliance = NULLIF(?,'') WHERE pid = ?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set alliance to: $value");
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('planet',$p->{id}));
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
	}else{
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

sub findPlanet : Private {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT x,y,z,pid AS id, nick, alliance,aid
		, planet_status,channel,ftid,gov
		FROM current_planet_stats
		WHERE pid = $1
		});
	$query->execute($id);
	$c->stash(p => $query->fetchrow_hashref);
}

sub members : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if (defined $order && $order =~ /^(attacks|defenses|attack_points|defense_points
			|solo|bad_def)$/x){
		$order = $1;
	}else{
		$order = 'attacks';
	}
	my $query = $dbh->prepare(q{SELECT u.uid,u.username,u.attack_points, u.defense_points, n.tick
		,count(CASE WHEN i.mission = 'Attack' THEN 1 ELSE NULL END) AS attacks
		,count(CASE WHEN (i.mission = 'Defend' OR i.mission = 'AllyDef') THEN 1 ELSE NULL END) AS defenses
		,count(CASE WHEN i.mission = 'Attack' AND rt.id IS NULL THEN 1 ELSE NULL END) AS solo
		,count(CASE WHEN i.mission = 'Defend' OR i.mission = 'AllyDef' THEN NULLIF(i.ingal OR (t.alliance_id = 1),TRUE) ELSE NULL END) AS bad_def
		FROM users u
		JOIN groupmembers gm USING (uid)
		LEFT OUTER JOIN (SELECT DISTINCT ON (planet) planet,tick from scans where type = 'News' ORDER BY planet,tick DESC) n USING (planet)
		LEFT OUTER JOIN (SELECT DISTINCT name,eta,tick,sender,target,mission,ingal FROM intel WHERE amount IS NULL) i ON i.sender = u.planet
		LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
		LEFT OUTER JOIN (SELECT rt.id,planet,tick FROM raids r 
				JOIN raid_targets rt ON r.id = rt.raid) rt ON rt.planet = i.target 
			AND (rt.tick + 12) > i.tick AND rt.tick <= i.tick 
		LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target AND rc.uid = u.uid AND i.tick = rt.tick + rc.wave - 1
		WHERE gm.gid = 2
		GROUP BY u.uid,u.username,u.attack_points, u.defense_points,n.tick
		ORDER BY }. " $order DESC" );
	$query->execute;
	$c->stash(members => $query->fetchall_arrayref({}) );
}

sub member : Local {
	my ( $self, $c, $uid ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{
		SELECT coords(t.x,t.y,t.z), i.eta, i.tick, rt.id AS ndtarget, rc.launched, inc.landing_tick
		FROM users u
		LEFT OUTER JOIN (SELECT DISTINCT eta,tick,sender,target,mission,name FROM intel WHERE amount IS NULL) i ON i.sender = u.planet
		LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
		LEFT OUTER JOIN (SELECT rt.id,planet,tick FROM raids r 
				JOIN raid_targets rt ON r.id = rt.raid) rt ON rt.planet = i.target 
			AND (rt.tick + 12) > i.tick AND rt.tick <= i.tick 
		LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target AND rc.uid = u.uid AND i.tick = rt.tick + rc.wave - 1
		LEFT OUTER JOIN (SELECT sender, eta, landing_tick FROM calls c 
					JOIN incomings i ON i.call = c.id) inc ON inc.sender = i.target 
				AND (inc.landing_tick + inc.eta) >= i.tick 
				AND (inc.landing_tick - inc.eta - 1) <= (i.tick - i.eta) 
		WHERE u.uid = $1 AND i.mission = 'Attack'
		ORDER BY (i.tick - i.eta)
		});
	$query->execute($uid);
	my @nd_attacks;
	my @other_attacks;
	while (my $intel = $query->fetchrow_hashref){
		my $attack = {target => $intel->{coords}, tick => $intel->{tick}};
		if ($intel->{ndtarget}){
			if (defined $intel->{launched}){
				$attack->{other} = 'Claimed '.($intel->{launched} ? 'and confirmed' : 'but NOT confirmed');
			}else{
				$attack->{other} = 'Launched at a tick that was not claimed';
			}
			push @nd_attacks, $attack;
		}else{
			push @other_attacks, $attack;
		}
	}
	my @attacks;
	push @attacks, {name => 'ND Attacks', missions => \@nd_attacks, class => 'AllyDef'};
	push @attacks, {name => 'Other', missions => \@other_attacks, class => 'Attack'};
	$c->stash(attacks => \@attacks);

	$query = $dbh->prepare(q{
		SELECT coords(t.x,t.y,t.z),t.alliance_id, t.alliance, i.eta, i.tick, i.ingal
		FROM users u
		JOIN (SELECT DISTINCT name,eta,tick,sender,target,mission,ingal FROM intel WHERE amount IS NULL) i ON i.sender = u.planet
		LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
		WHERE u.uid = $1 AND (i.mission = 'Defend' OR i.mission = 'AllyDef')
		ORDER BY (i.tick - i.eta)
		});
	$query->execute($uid);
	my @nd_def;
	my @ingal_def;
	my @other_def;
	while (my $intel = $query->fetchrow_hashref){
		my $def = {target => $intel->{coords}, other => $intel->{alliance}, tick => $intel->{tick}};
		if (defined $intel->{alliance_id} && $intel->{alliance_id} == 1){
			push @nd_def, $def;
		}elsif($intel->{ingal}){
			push @ingal_def, $def;
		}else{
			push @other_def, $def;
		}
	}
	my @defenses;
	push @defenses, {name => 'ND Def', missions => \@nd_def, class => 'AllyDef'};
	push @defenses, {name => 'Ingal Def', missions => \@ingal_def, class => 'Defend'};
	push @defenses, {name => 'Other', missions => \@other_def, class => 'Attack'};
	$c->stash(defenses => \@defenses);
}

sub naps : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT pid AS id,coords(x,y,z)
		,ruler, p.planet,race, size, score, value
		, xp, sizerank, scorerank, valuerank, xprank, p.value - p.size*200 
			- COALESCE(ps.metal+ps.crystal+ps.eonium,0)/150
			- COALESCE(ds.total ,(SELECT COALESCE(avg(total),0)
				FROM current_development_scans)::int)*1500 AS fleetvalue
		,(metal+crystal+eonium)/100 AS resvalue, planet_status,hit_us
		, alliance,relationship,nick
		FROM current_planet_stats p
			LEFT OUTER JOIN current_planet_scans ps USING (pid)
			LEFT OUTER JOIN current_development_scans ds USING (pid)
		WHERE planet_status IN ('Friendly','NAP') order by x,y,z asc
		});
	$query->execute;
	$c->stash(planets => $query->fetchall_arrayref({}) );
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
