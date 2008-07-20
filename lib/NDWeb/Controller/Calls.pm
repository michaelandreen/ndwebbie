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

	my $where = q{open AND c.landing_tick-6 > tick()};
	my $order = q{landing_tick DESC, defprio DESC};
	if (defined $type){
		if ($type eq 'covered'){
			$where = 'covered';
		}elsif ($type eq 'all'){
			$where = 'true';
		}elsif ($type eq 'uncovered'){
			$where = 'not covered';
		}elsif ($type eq 'recent'){
			$where = q{c.landing_tick > tick()};
			$order = q{x,y,z};
		}
	}
	my $pointlimits = $dbh->prepare(q{SELECT value :: float FROM misc WHERE id = ?});
	$c->stash(minprio => $dbh->selectrow_array($pointlimits,undef,'DEFMINPRIO'));
	$c->stash(maxprio => $dbh->selectrow_array($pointlimits,undef,'DEFMAXPRIO'));

	my $query = $dbh->prepare(qq{
		SELECT id,coords(x,y,z),planet,landing_tick,dc,curreta,fleets
			,(0.2*(attack_points/a.attack)+ 0.4*(defense_points/a.defense)
				+ 0.2*(c.size/a.size) + 0.05*(c.score/a.score)
				+ 0.15*(c.value/a.value))::Numeric(3,2) AS defprio
			,array_accum(race::text) AS race
			,array_accum(amount) AS amount
			,array_accum(eta) AS eta
			,array_accum(shiptype) AS shiptype
			,array_accum(COALESCE(alliance,'?')) AS alliance
			,array_accum(coords) AS attackers
		FROM (SELECT c.id, p.x,p.y,p.z,p.id AS planet, p.size, p.value, p.score
			,u.defense_points, u.attack_points, c.landing_tick
			,dc.username AS dc, (c.landing_tick - tick()) AS curreta
			,p2.race, i.amount, i.eta, i.shiptype, p2.alliance
			,coords(p2.x,p2.y,p2.z),	COUNT(DISTINCT f.id) AS fleets
			FROM calls c 
				JOIN users u ON c.member = u.uid
				JOIN current_planet_stats p ON u.planet = p.id
				LEFT OUTER JOIN incomings i ON i.call = c.id
				LEFT OUTER JOIN current_planet_stats p2 ON i.sender = p2.id
				LEFT OUTER JOIN users dc ON c.dc = dc.uid
				LEFT OUTER JOIN fleets f ON f.target = u.planet 
					AND f.tick = c.landing_tick AND f.back = f.tick + f.eta - 1
			WHERE $where
			GROUP BY c.id, p.x,p.y,p.z,p.id, p.size, p.score, p.value, c.landing_tick
				,u.defense_points,u.attack_points,dc.username
				,p2.race,i.amount,i.eta,i.shiptype,p2.alliance,p2.x,p2.y,p2.z
			) c
			,(SELECT avg(attack_points) AS attack, avg(defense_points) AS defense
				, avg(size) AS size, avg(score) AS score, avg(value) AS value
				FROM users u JOIN current_planet_stats p ON p.id = u.planet
				WHERE uid IN (SELECT uid FROM groupmembers  where gid = 2)
			) a
		GROUP BY id, x,y,z,planet,landing_tick, defense_points, attack_points
			,dc,curreta,fleets, c.size, c.score, c.value
			, a.attack, a.defense, a.size, a.score, a.value
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
		SELECT i.id,i.mission, i.name, i.tick,eta
			, i.amount, coords(x,y,z) AS coords, t.id AS planet
		FROM fleets i
		LEFT OUTER JOIN (planets
			NATURAL JOIN planet_stats) t ON i.target = t.id
				AND t.tick = ( SELECT MAX(tick) FROM planet_stats)
		WHERE  i.sender = $1 
			AND (i.tick > $2 - 14 OR i.mission = 'Full fleet')
		ORDER BY i.tick,x,y,z
	});
	my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
		WHERE id = ? ORDER BY num
		});
	$outgoings->execute($call->{planet},$call->{landing_tick});
	my @fleets;
	while (my $fleet = $outgoings->fetchrow_hashref){
		if (defined $fleet->{back} &&
				$fleet->{back} == $call->{landing_tick}){
			$fleet->{fleetcatch} = 1;
		}
		$ships->execute($fleet->{id});
		if ($ships->rows != 0){
			my @ships;
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			$fleet->{ships} = \@ships;
		}
		push @fleets, $fleet;
	}
	$c->stash(fleets => \@fleets);

	my $defenders = $dbh->prepare(q{ 
		SELECT DISTINCT ON (i.tick,x,y,z,s.id,i.name,i.amount) i.id,i.mission, i.name, i.tick,eta
			, i.amount, coords(x,y,z) AS coords, s.id AS planet
		FROM fleets i
		LEFT OUTER JOIN (planets
			NATURAL JOIN planet_stats) s ON i.sender = s.id
				AND s.tick = ( SELECT MAX(tick) FROM planet_stats)
		WHERE i.target = ?
			AND i.tick = ? AND i.mission = 'Defend'
		ORDER BY i.tick,x,y,z
	});

	$defenders->execute($call->{planet},$call->{landing_tick});
	my @defenders;
	while (my $fleet = $defenders->fetchrow_hashref){
		$ships->execute($fleet->{id});
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
			,i.fleet,i.shiptype,p.relationship,p.alliance,i.id,p.id AS planet
		FROM incomings i
			JOIN current_planet_stats p ON i.sender = p.id
		WHERE i.call = ?
		ORDER BY p.x,p.y,p.z
	});
	$attackers->execute($call->{id});
	my @attackers;
	while(my $attacker = $attackers->fetchrow_hashref){
		$outgoings->execute($attacker->{planet},$call->{landing_tick});
		my @missions;
		while (my $mission = $outgoings->fetchrow_hashref){
			$ships->execute($mission->{id});
			if ($ships->rows != 0){
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
}

sub defleeches : Local {
	my ( $self, $c, $type ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT username,defense_points,count(id) AS calls
		, SUM(fleets) AS fleets, SUM(recalled) AS recalled
		FROM (SELECT username,defense_points,c.id,count(f.target) AS fleets
			, count(NULLIF(f.tick + f.eta -1 = f.back,TRUE)) AS recalled
			FROM users u JOIN calls c ON c.member = u.uid
				LEFT OUTER JOIN fleets f ON u.planet = f.target
					AND c.landing_tick = f.tick
			WHERE (f.mission = 'Defend' AND f.uid > 0 AND f.back IS NOT NULL AND NOT ingal)
				OR f.target IS NULL
			GROUP BY username,defense_points,c.id
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
	$c->res->redirect($c->uri_for('edit',$call->{id}));
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
		if ($c->req->param('ctick')){
			$dbh->do(q{UPDATE calls SET landing_tick = ? WHERE id = ?}
				,undef,$c->req->param('tick'),$call->{id});
			$log->execute($c->user->id,$call->{ftid}
				,"Updated landing tick from [B] $call->{landing_tick} [/B]");
		}
		if ($c->req->param('cinfo')){
			$dbh->do(q{UPDATE calls SET info = ? WHERE id = ?}
				,undef,$c->req->param('info'),$call->{id});
			$log->execute($c->user->id,$call->{ftid},"Updated info");
		}
	}elsif($c->req->param('cmd') =~ /^(Cover|Uncover|Ignore|Open|Take) call$/){
		my $extra_vars = '';
		if ($1 eq 'Cover'){
			$extra_vars = ", covered = TRUE, open = FALSE";
		}elsif ($1 eq 'Uncover'){
			$extra_vars = ", covered = FALSE, open = TRUE";
		}elsif ($1 eq 'Ignore'){
			$extra_vars = ", covered = FALSE, open = FALSE";
		}elsif ($1 eq 'Open'){
			$extra_vars = ", covered = FALSE, open = TRUE";
		}
		$dbh->do(qq{UPDATE calls SET dc = ? $extra_vars WHERE id = ?},
			,undef,$c->user->id,$call->{id});
		$log->execute($c->user->id,$call->{ftid}
			,'Changed status to: [B]'.$c->req->param('cmd').'[/B]');
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$call->{id}));
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
		my $query = $dbh->prepare(q{DELETE FROM incomings WHERE id = ? AND call = ?});
		my $inc = $dbh->prepare(q{SELECT sender,eta,amount FROM incomings WHERE id = $1});
		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				my ($planet,$eta,$amount) = $dbh->selectrow_array($inc,undef,$1);
				$query->execute($1,$call->{id});
				$log->execute($c->user->id,$call->{ftid}
					,"Deleted fleet: [B] $1 [/B] ($planet:$eta:$amount)");
			}
		}
	}elsif($c->req->param('cmd') eq 'Change'){
		my $query = $dbh->prepare(q{UPDATE incomings SET shiptype = ?
			WHERE id = ? AND call = ?
		});
		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				my $shiptype = html_escape($c->req->param("shiptype:$1"));
				$query->execute($shiptype,$1,$call->{id});
				$log->execute($c->user->id,$call->{ftid}
					,"set fleet: [B] $1 [/B] to: [B] $shiptype [/B]");
			}
		}
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$call->{id}));
}

sub findCall : Private {
	my ( $self, $c, $call) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{
		SELECT c.id, coords(p.x,p.y,p.z), c.landing_tick, c.info, covered
			,open, dc.username AS dc, u.defense_points,c.member
			,u.planet, u.username AS member, u.sms,c.ftid
		FROM calls c 
		JOIN users u ON c.member = u.uid
		LEFT OUTER JOIN users dc ON c.dc = dc.uid
		JOIN current_planet_stats p ON u.planet = p.id
		WHERE c.id = ?
		});
	$call = $dbh->selectrow_hashref($query,undef,$call);

	$c->assert_user_roles(qw/calls_edit/) unless $c->user->id == $call->{member};
	$c->stash(call => $call);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
