package NDWeb::Controller::Calls;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Calls - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index : Path : Args(0) {
	my ( $self, $c) = @_;

	$c->stash(template => 'calls/list.tt2');
	$c->forward('list');
}

sub list : Local {
	my ( $self, $c, $type ) = @_;
	my $dbh = $c->model;

	my $where = q{status = 'Open' AND landing_tick-6 > tick()};
	my $order = q{landing_tick DESC, defprio DESC};
	if (defined $type){
		if ($type eq 'covered'){
			$where = q{status = 'Covered'};
		}elsif ($type eq 'all'){
			$where = 'true';
		}elsif ($type eq 'uncovered'){
			$where = q{status <> 'Covered'};
		}elsif ($type eq 'recent'){
			$where = q{landing_tick >= tick()};
			$order = q{x,y,z};
		}
	}
	my $pointlimits = $dbh->prepare(q{SELECT value :: float FROM misc WHERE id = ?});
	$c->stash(minprio => $dbh->selectrow_array($pointlimits,undef,'DEFMINPRIO'));
	$c->stash(maxprio => $dbh->selectrow_array($pointlimits,undef,'DEFMAXPRIO'));

	my $query = $dbh->prepare(qq{
SELECT *, pid AS planet, coords(x,y,z)
FROM full_defcalls
WHERE $where
ORDER BY $order
		});
	$query->execute;
	$c->stash(calls => $query->fetchall_arrayref({}));
}

sub edit : Local {
	my ( $self, $c, $call) = @_;
	my $dbh = $c->model;

	$c->forward('findCall');
	$call = $c->stash->{call};


	$c->stash(cover => ($call->{covered} ? 'Uncover' : 'Cover'));
	if ($call->{open} && !$call->{covered}){
		$c->stash(ignore => 'Ignore');
	}else{
		$c->stash(ignore => 'Open');
	}


	my $outgoings = $dbh->prepare(q{ 
(
	SELECT DISTINCT ON (mission,name) 1 AS type, fid,mission,name,tick, NULL AS eta
		,amount, NULL AS coords, pid AS planet, NULL AS back, NULL AS recalled
	FROM fleets f
	WHERE pid = $1 AND tick <= $2 AND (
			mission = 'Full fleet'
			OR fid IN (SELECT fid FROM fleet_scans)
		) AND (
			mission = 'Full fleet'
			OR tick >= $2 - 12
		)
	ORDER BY mission,name,tick DESC
) UNION (
	SELECT 2 AS type, MAX(fid) AS fid,mission,name,landing_tick AS tick, eta, amount
		, coords(x,y,z), pid AS planet, back
		, (back <> landing_tick + eta - 1) AS recalled
	FROM launch_confirmations
		JOIN (
			SELECT fid,amount,name,mission FROM fleets WHERE pid = $1
		) f  USING (fid)
		LEFT OUTER JOIN current_planet_stats t USING (pid)
	WHERE back >= $2 AND landing_tick - eta - 12 < $2
	GROUP BY mission,name,landing_tick,eta,amount,back,x,y,z,pid
) UNION (
	SELECT DISTINCT ON (tick,x,y,z,mission,name,amount)
		3 AS type, NULL as fid, i.mission, i.name, i.tick,eta
		, i.amount, coords(x,y,z), t.pid AS planet, back, NULL AS recalled
	FROM intel i
	LEFT OUTER JOIN current_planet_stats t ON i.target = t.pid
	WHERE uid = -1 AND i.sender = $1 AND i.tick > $2 - 14 AND i.tick < $2 + 14
	ORDER BY i.tick,x,y,z,mission,name,amount,back
) ORDER BY type, mission,name,tick DESC
	});
	my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
		WHERE fid = ? ORDER BY num
		});
	$outgoings->execute($call->{pid},$call->{landing_tick});
	my @fleets;
	while (my $fleet = $outgoings->fetchrow_hashref){
		if (defined $fleet->{back} &&
				$fleet->{back} == $call->{landing_tick}){
			$fleet->{fleetcatch} = 1;
		}
		if ($fleet->{fid}){
			$ships->execute($fleet->{fid});
			my @ships;
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
			$fleet->{ships} = \@ships;
		}
		push @fleets, $fleet;
	}

	my $available = $dbh->prepare(q{
SELECT ship,amount from ships_home WHERE pid = $1 AND tick = $2
		});
	$available->execute($call->{pid}, $call->{landing_tick});
	my $fleet = {fid => $call->{member}, mission => 'Available'
		, name => 'At home', ships => $available->fetchall_arrayref({})
	};
	push @fleets, $fleet;

	$c->stash(fleets => \@fleets);

	my $defenders = $dbh->prepare(q{
SELECT DISTINCT ON (x,y,z,pid,name,amount,back) fid,mission, name, eta
	, amount, coords(x,y,z) AS coords, landing_tick AS tick, pid AS planet
	,back, (back <> landing_tick + eta - 1) AS recalled
FROM fleets f
	LEFT OUTER JOIN current_planet_stats s USING (pid)
	JOIN (
		SELECT fid,back,eta,landing_tick
		FROM launch_confirmations
		WHERE pid = $1 AND landing_tick = $2
	) lc USING (fid)
WHERE mission IN ('Defend', 'Fake Defend')
ORDER BY x,y,z
	});

	$defenders->execute($call->{pid},$call->{landing_tick});
	my @defenders;
	while (my $fleet = $defenders->fetchrow_hashref){
		$ships->execute($fleet->{fid});
		if ($ships->rows != 0){
			my @ships;
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			$fleet->{ships} = \@ships;
		}
		push @defenders, $fleet;
	}
	$c->stash(defenders => \@defenders);

	my $attackers = $dbh->prepare(q{
		SELECT coords(p.x,p.y,p.z), p.planet_status, p.race,i.eta,i.amount
			,i.fleet,i.shiptype,p.relationship,p.alliance,inc,pid
		FROM incomings i
			JOIN current_planet_stats p USING (pid)
		WHERE i.call = ?
		ORDER BY p.x,p.y,p.z
	});
	$attackers->execute($call->{call});
	my @attackers;
	while(my $attacker = $attackers->fetchrow_hashref){
		$outgoings->execute($attacker->{pid},$call->{landing_tick});
		my @missions;
		while (my $mission = $outgoings->fetchrow_hashref){
			if ($mission->{fid}){
				$ships->execute($mission->{fid});
				my @ships;
				while (my $ship = $ships->fetchrow_hashref){
					push @ships,$ship;
				}
				push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
				$mission->{ships} = \@ships;
			}
			push @missions,$mission;
		}
		$attacker->{missions} = \@missions;
		push @attackers,$attacker;
	}
	$c->stash(attackers => \@attackers);

	$c->forward('/forum/findPosts',[$call->{ftid}]);

	my $statuses = $dbh->prepare(q{
SELECT status FROM call_statuses
		});
	$statuses->execute;
	$c->stash(statuses => $statuses->fetchall_arrayref({}));
}

sub defleeches : Local {
	my ( $self, $c, $type ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT username,defense_points,count(call) AS calls
		, SUM(fleets) AS fleets, SUM(recalled) AS recalled
		,count(NULLIF(fleets,0)) AS defended_calls
		FROM (SELECT username,defense_points,call,count(f.back) AS fleets
			, count(NULLIF(f.landing_tick + f.eta -1 = f.back,TRUE)) AS recalled
			FROM users u JOIN calls c USING (uid)
				LEFT OUTER JOIN (
					SELECT lc.pid,landing_tick,eta,back
					FROM launch_confirmations lc JOIN fleets f USING (fid)
					WHERE mission = 'Defend'
				) f USING (pid,landing_tick)
			GROUP BY username,defense_points,call
		) d
		GROUP BY username,defense_points ORDER BY fleets DESC, defense_points
		});
	$query->execute;

	$c->stash(members => $query->fetchall_arrayref({}) );
}

sub postcallcomment : Local {
	my ($self, $c, $call) = @_;

	$c->forward('findCall');
	$call = $c->stash->{call};

	$c->forward('/forum/insertPost',[$call->{ftid}]);
	$c->res->redirect($c->uri_for('edit',$call->{call}));
}

sub postcallupdate : Local {
	my ($self, $c, $call) = @_;
	my $dbh = $c->model;

	$c->forward('findCall');
	$call = $c->stash->{call};

	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message)
		VALUES($2,$1,$3)
		});

	$dbh->begin_work;
	if ($c->req->param('cmd') eq 'Submit'){
		my $logmess = '';
		if ($c->req->param('ctick')){
			$dbh->do(q{UPDATE calls SET landing_tick = ? WHERE call = ?}
				,undef,$c->req->param('tick'),$call->{call});
			$logmess .= "Updated landing tick from [B] $call->{landing_tick} [/B]\n";
		}
		if ($c->req->param('cinfo')){
			$dbh->do(q{UPDATE calls SET info = ? WHERE call = ?}
				,undef,$c->req->param('info'),$call->{call});
			$logmess .= "Updated info\n";
		}
		if ($c->req->param('ccalc')){
			my $calc = $c->req->param('calc');
			$dbh->do(q{UPDATE calls SET calc = ? WHERE call = ?}
				,undef,$calc,$call->{call});
			$logmess .= html_escape('Updated calc to: [URL]'.$calc."[/URL]\n");
		}
		if ($c->req->param('cstatus')){
			$dbh->do(q{UPDATE calls SET status = $1, dc = $2 WHERE call = $3}
				,undef,$c->req->param('status'),$c->user->id,$call->{call});
			$logmess .= "Changed status to: ".$c->req->param('status')."\n";
		}
		$log->execute($c->user->id,$call->{ftid},$logmess) if $log;
	}elsif($c->req->param('cmd') =~ /^Take call$/){
		my $extra_vars = '';
		$dbh->do(q{UPDATE calls SET dc = ? WHERE call = ?},
			,undef,$c->user->id,$call->{call});
		$log->execute($c->user->id,$call->{ftid}
			,'Changed status to: [B]'.$c->req->param('cmd').'[/B]');
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$call->{call}));
}


sub postattackerupdate : Local {
	my ($self, $c, $call) = @_;
	my $dbh = $c->model;

	$c->forward('findCall');
	$call = $c->stash->{call};

	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message)
		VALUES($2,$1,$3)
		});

	$dbh->begin_work;
	if($c->req->param('cmd') eq 'Remove'){
		my $query = $dbh->prepare(q{DELETE FROM incomings WHERE inc = ? AND call = ?});
		my $inc = $dbh->prepare(q{SELECT pid,eta,amount FROM incomings WHERE inc = $1});
		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				my ($planet,$eta,$amount) = $dbh->selectrow_array($inc,undef,$1);
				$query->execute($1,$call->{call});
				$log->execute($c->user->id,$call->{ftid}
					,"Deleted fleet: [B] $1 [/B] ($planet:$eta:$amount)");
			}
		}
	}elsif($c->req->param('cmd') eq 'Change'){
		my $query = $dbh->prepare(q{UPDATE incomings SET shiptype = ?
			WHERE inc = ? AND call = ?
		});
		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				my $shiptype = html_escape($c->req->param("shiptype:$1"));
				$query->execute($shiptype,$1,$call->{call});
				$log->execute($c->user->id,$call->{ftid}
					,"set fleet: [B] $1 [/B] to: [B] $shiptype [/B]");
			}
		}
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$call->{call}));
}

sub findCall : Private {
	my ( $self, $c, $call) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{
		SELECT call, coords(p.x,p.y,p.z), c.landing_tick, c.info, status
			,dc.username AS dc, u.defense_points,c.uid
			,p.pid, u.username AS member, u.sms,c.ftid,calc
		FROM calls c
		JOIN users u USING (uid)
		JOIN current_planet_stats p USING (pid)
		LEFT OUTER JOIN users dc ON c.dc = dc.uid
		WHERE call = ?
		});
	$call = $dbh->selectrow_hashref($query,undef,$call);

	$c->assert_user_roles(qw/calls_edit/) unless $c->user->id == $call->{uid};
	$c->stash(call => $call);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
