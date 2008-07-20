package NDWeb::Controller::Members;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Members - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index : Path : Args(0) {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	$c->stash(error => $c->flash->{error});

	$c->stash(comma => \&comma_value);
	$c->stash(u => $dbh->selectrow_hashref(q{SELECT planet,defense_points
			,attack_points,scan_points,humor_points
			, (attack_points+defense_points+scan_points/20) as total_points
			, sms,rank,hostmask FROM users WHERE uid = ?
			},undef,$c->user->id)
	);

	$c->stash(groups => $dbh->selectrow_array(q{SELECT array_accum(groupname)
		FROM groups g NATURAL JOIN groupmembers gm
		WHERE uid = $1
			},undef,$c->user->id)
	);

	$c->stash(p => $dbh->selectrow_hashref(q{SELECT id,x,y,z, ruler, planet,race,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day
		from current_planet_stats_full p
			WHERE id = ?
			},undef,$c->user->planet)
	);

	my $calls = $dbh->prepare(q{
		SELECT id,landing_tick,dc,curreta
			,array_accum(race::text) AS race
			,array_accum(amount) AS amount
			,array_accum(eta) AS eta
			,array_accum(shiptype) AS shiptype
			,array_accum(coords) AS attackers
		FROM (SELECT c.id, c.landing_tick
			,dc.username AS dc, (c.landing_tick - tick()) AS curreta
			,p2.race, i.amount, i.eta, i.shiptype, p2.alliance
			,coords(p2.x,p2.y,p2.z)
			FROM calls c
				LEFT OUTER JOIN incomings i ON i.call = c.id
				LEFT OUTER JOIN current_planet_stats p2 ON i.sender = p2.id
				LEFT OUTER JOIN users dc ON c.dc = dc.uid
			WHERE c.member = $1 AND c.landing_tick >= tick()
			GROUP BY c.id, c.landing_tick, dc.username
				,p2.race,i.amount,i.eta,i.shiptype,p2.alliance,p2.x,p2.y,p2.z
			) c
		GROUP BY id, landing_tick,dc,curreta
		});

	$calls->execute($c->user->id);
	$c->stash(calls => $calls->fetchall_arrayref({}) );

	my $query = $dbh->prepare(q{SELECT f.id, coords(x,y,z), target, mission
		, f.amount, tick, back
FROM fleets f
LEFT OUTER JOIN current_planet_stats p ON f.target = p.id
WHERE NOT ingal AND f.uid = ? AND f.sender = ? AND
	(back >= ? OR (tick >= tick() -  24 AND name = 'Main'))
GROUP BY f.id, x,y,z, mission, tick,back,f.amount,f.target
ORDER BY x,y,z,mission,tick
		});

	my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
		WHERe id = ? ORDER BY num
		});

	$query->execute($c->user->id,$c->user->planet,$c->stash->{TICK});
	my @fleets;
	while (my $fleet = $query->fetchrow_hashref){
		my @ships;
		$ships->execute($fleet->{id});
		while (my $ship = $ships->fetchrow_hashref){
			push @ships,$ship;
		}
		$fleet->{ships} = \@ships;
		push @fleets,$fleet;
	}
	$c->stash(fleets => \@fleets);

	my $announcements = $dbh->prepare(q{SELECT ft.ftid, u.username,ft.subject,
		count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts,
		date_trunc('seconds',max(fp.time)::timestamp) as last_post,
		min(fp.time)::date as posting_date, ft.sticky
		FROM forum_threads ft JOIN forum_posts fp USING (ftid)
			JOIN users u ON u.uid = ft.uid
			LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1) ftv ON ftv.ftid = ft.ftid
		WHERE ft.fbid = 1
		GROUP BY ft.ftid, ft.subject,ft.sticky,u.username
		HAVING count(NULLIF(COALESCE(ft.sticky OR fp.time > ftv.time,TRUE),FALSE)) >= 1
		ORDER BY sticky DESC,last_post DESC
		});
	$announcements->execute($c->user->id);
	$c->stash(announcements => $announcements->fetchall_arrayref({}) );
}

sub posthostupdate : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$dbh->do(q{UPDATE users SET hostmask = ? WHERE uid = ?
		},undef, html_escape $c->req->param('hostname'), $c->user->id);

	$c->res->redirect($c->uri_for(''));
}

sub postsmsupdate : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$dbh->do(q{UPDATE users SET sms = ? WHERE uid = ?
		},undef, html_escape $c->req->param('sms'), $c->user->id);

	$c->res->redirect($c->uri_for(''));
}

sub postfleetupdate : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $fleet = $c->req->param('fleet');
	$fleet =~ s/,//g;
	my $amount = 0;
	my @ships;
	while ($fleet =~ m/((?:[A-Z][a-z]+ )*[A-Z][a-z]+)\s+(\d+)/g){
		$amount += $2;
		push @ships, [$1,$2];
	}
	if ($amount){
		$dbh->begin_work;
		eval{
			my $insert = $dbh->prepare(q{INSERT INTO fleets
				(uid,sender,name,mission,tick,amount)
				VALUES (?,?,'Main','Full fleet',tick(),?) RETURNING id});
			my ($id) = $dbh->selectrow_array($insert,undef,$c->user->id
				,$c->user->planet,$amount);
			$insert = $dbh->prepare(q{INSERT INTO fleet_ships
				(id,ship,amount) VALUES (?,?,?)});
			for my $s (@ships){
				unshift @{$s},$id;
				$insert->execute(@{$s});
			}
			$dbh->commit;
		};
		if ($@){
			if ($@ =~ m/insert or update on table "fleet_ships" violates foreign key constraint "fleet_ships_ship_fkey"\s+DETAIL:\s+Key \(ship\)=\(([^)]+)\)/){
				$c->flash( error => "'$1' is NOT a valid ship");
			}else{
				$c->flash( error => $@);
			}
			$dbh->rollback;
		}
	}else{
		$c->flash( error => 'Fleet does not contain any ships');
	}

	$c->res->redirect($c->uri_for(''));
}

sub postfleetsupdates : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)
		});
	$dbh->begin_work;
	if ($c->req->param('cmd') eq 'Recall Fleets'){
		my $updatefleets = $dbh->prepare(q{UPDATE fleets
			SET back = tick() + (tick() - (tick - eta))
			WHERE uid = ? AND id = ? AND back > tick()+eta
		});

		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				$updatefleets->execute($c->user->id,$1);
				$log->execute($c->user->id,"Member recalled fleet $1");
			}
		}
	}elsif ($c->req->param('cmd') eq 'Change Fleets'){
		my $updatefleets = $dbh->prepare(q{UPDATE fleets
			SET back = ? WHERE uid = ? AND id = ?});

		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				my $back = $c->req->param("back:$1");
				$updatefleets->execute($back,$c->user->id,$1);
				$log->execute($c->user->id,"Member set fleet $1 to be back tick: $back");
			}
		}
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for(''));
}

sub ircrequest : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$c->stash(reply => $c->flash->{reply});
	$c->stash(channels => ['def','scan','members']);
}

sub postircrequest : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{INSERT INTO irc_requests
		(uid,channel,message) VALUES($1,$2,$3)
		});
	$query->execute($c->user->id,$c->req->param('channel'),$c->req->param('message'));

	$c->flash(reply => "Msg sent to: ".$c->req->param('channel'));
	$c->res->redirect($c->uri_for('ircrequest'));
}

sub points : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if ($order && $order =~ /^((?:defense|attack|total|humor|scan|raid)_points)$/){
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

sub addintel : Local {
	my ( $self, $c, $order ) = @_;

	$c->stash(intel => $c->flash->{intel});
	$c->stash(scans => $c->flash->{scans});
	$c->stash(intelmessage => $c->flash->{intelmessage});
}

sub postintel : Local {
	my ( $self, $c, $order ) = @_;

	$c->forward('insertintel');

	$c->res->redirect($c->uri_for('addintel'));
}

sub postintelmessage : Local {
	my ( $self, $c, $order ) = @_;

	unless ($c->req->param('subject')){
		if ($c->req->param('message') =~ /(.*\w.*)/){
			$c->req->param(subject => $1);
		}
	}

	$c->forward('/forum/insertThread',[12]);
	$c->forward('/forum/insertPost',[$c->stash->{thread}]);
	$c->flash(intelmessage => 1);

	$c->forward('insertintel');

	$c->res->redirect($c->uri_for('addintel'));
}

sub insertintel : Private {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $findscan = $dbh->prepare(q{SELECT scan_id FROM scans
		WHERE scan_id = ? AND tick >= tick() - 168 AND groupscan = ?
		});
	my $addscan = $dbh->prepare(q{INSERT INTO scans (scan_id,tick,uid,groupscan)
		VALUES (?,tick(),?,?)
		});
	my $addpoint = $dbh->prepare(q{UPDATE users SET scan_points = scan_points + 1
		WHERE uid = ?
		});
	my @scans;
	my $intel = $c->req->param('message');
	while ($intel =~ m{http://[\w.]+/.+?scan(_id|_grp)?=(\d+)}g){
		my $groupscan = (defined $1 && $1 eq '_grp') || 0;
		my %scan;
		$scan{id} = $2;
		$scan{group} = $groupscan;
		$findscan->execute($2,$groupscan);
		if ($findscan->rows == 0){
			if ($addscan->execute($2,$c->user->id,$groupscan)){
				$addpoint->execute($c->user->id) unless $groupscan;
				$scan{added} = 1;
			}
		}else{
			$scan{message} = 'already exists';
		}
		push @scans,\%scan;
	}
	my $tick = $c->req->param('tick');
	unless ($tick =~ /^(\d+)$/){
		$tick = $c->stash->{game}->{tick};
	}
	my $addintel = $dbh->prepare(q{INSERT INTO fleets 
		(name,mission,tick,target,sender,eta,amount,ingal,back,uid)
		VALUES($1,$2,$3,planetid($4,$5,$6,$10),planetid($7,$8,$9,$10)
			,$11,$12,$13,$14,$15)
	});
	my @intel;
	while ($intel =~ m/(\d+):(\d+):(\d+)\*?\s+(\d+):(\d+):(\d+)
		\*?\s+(.+)(?:Ter|Cat|Xan|Zik|Etd)?
		\s+(\d+)\s+(Attack|Defend)\s+(\d+)/gx){
		my $ingal = ($1 == $4 && $2 == $5) || 0;
		my $lt = $tick + $10;
		my $back = ($ingal ? $lt + 4 : undef);
		eval {
			$addintel->execute($7,$9,$lt,$1,$2,$3,$4,$5,$6,$tick,$10,$8
				,$ingal,$back, $c->user->id);
			push @intel,"Added $&";
		};
		if ($@){
			push @intel,"Couldn't add $&: ".$dbh->errstr;
		}
	}
	$dbh->commit;
	$c->flash(intel => \@intel);
	$c->flash(scans => \@scans);
}

sub launchConfirmation : Local {
	my ( $self, $c ) = @_;

	$c->stash(missions => $c->flash->{missions});
}

sub postconfirmation : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	eval {
		my $missions = $c->req->param('mission');
		my $findplanet = $dbh->prepare("SELECT planetid(?,?,?,?)");
		my $findattacktarget = $dbh->prepare(q{SELECT c.target,c.wave,c.launched
			FROM  raid_claims c
				JOIN raid_targets t ON c.target = t.id
				JOIN raids r ON t.raid = r.id
			WHERE c.uid = ? AND r.tick+c.wave-1 = ? AND t.planet = ?
				AND r.open AND not r.removed
			});
		my $finddefensetarget = $dbh->prepare(q{SELECT c.id FROM calls c
				JOIN users u ON c.member = u.uid
			WHERE u.planet = $1 AND c.landing_tick = $2
		});
		my $informDefChannel = $dbh->prepare(q{INSERT INTO defense_missions
			(fleet,call) VALUES (?,?)
			});
		my $addattackpoint = $dbh->prepare(q{UPDATE users SET
			attack_points = attack_points + 1 WHERE uid = ?
			});
		my $launchedtarget = $dbh->prepare(q{UPDATE raid_claims SET launched = True
			WHERE uid = ? AND target = ? AND wave = ?
			});
		my $addfleet = $dbh->prepare(q{INSERT INTO fleets
			(uid,name,mission,sender,target,tick,eta,back,amount)
			VALUES ($1,$2,$3,(SELECT planet FROM users WHERE uid = $1),$4,$5,$6,$7,$8)
			RETURNING id
			});
		my $addships = $dbh->prepare(q{INSERT INTO fleet_ships (id,ship,amount)
			VALUES (?,?,?)
			});
		my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
			(SELECT ftid FROM users WHERE uid = $1),$1,$2)
			});
		my @missions;
		$dbh->begin_work;
		while ($missions && $missions =~ m/([^\n]+)\s+(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)
			\s+\((?:(\d+)\+)?(\d+)\).*?(?:\d+hrs\s+)?\d+mins?\s+
			(Attack|Defend|Return|Fake\ Attack|Fake\ Defend)
			(.*?)
			(?:Launching\ in\ tick\ (\d+),\ arrival\ in\ tick\ (\d+)
				|ETA:\ \d+,\ Return\ ETA:\ (\d+)
				|Return\ ETA:\ (\d+)
				)/sgx){
			next if $10 eq 'Return';
			my %mission;
			my $name = $1;
			my $tick = $c->stash->{TICK}+$9;
			$tick += $8 if defined $8;
			my $eta = $9;
			my $mission = $10;
			my $x = $5;
			my $y = $6;
			my $z = $7;
			my $back = $tick + $eta - 1;
			if ($13){
				$tick = $13;
			}elsif ($14){
				$back += $14;
			}
			$mission{tick} = $tick;
			$mission{mission} = $mission;
			$mission{target} = "$x:$y:$z";
			$mission{back} = $back;

			my ($planet_id) = $dbh->selectrow_array($findplanet,undef,$x,$y,$z,$c->stash->{TICK});

			my $findtarget = $finddefensetarget;
			if ($mission eq 'Attack'){
				$findtarget = $findattacktarget;
				$findtarget->execute($c->user->id,$tick,$planet_id);
			}elsif ($mission eq 'Defend'){
				$findtarget = $finddefensetarget;
				$findtarget->execute($planet_id,$tick);
			}

			my $ships = $11;
			my @ships;
			my $amount = 0;
			while ($ships =~ m/((?:\w+ )*\w+)\s+\w+\s+(?:(?:\w+|-)\s+){3}(?:Steal|Normal|Emp|Normal\s+Cloaked|Pod|Structure Killer)\s+(\d+)/g){
				$amount += $2;
				push @ships,{ship => $1, amount => $2};
			}
			$mission{ships} = \@ships;

			if ($amount == 0){
				warn "No ships in: $ships";
				next;
			}
			my $fleet = $dbh->selectrow_array($addfleet,undef,$c->user->id,$name,$mission
				,$planet_id,$tick,$eta,$back,$amount);
			$mission{fleet} = $fleet;
			for my $ship (@ships){
				$addships->execute($fleet,$ship->{ship},$ship->{amount});
			}

			if ($findtarget->rows == 0){
				$mission{warning} = 'No matching target!';
			}elsif ($mission eq 'Attack'){
				my $claim = $findtarget->fetchrow_hashref;
				if ($claim->{launched}){
					$mission{warning} = "Already launched on this target:$claim->{target},$claim->{wave},$claim->{launched}";
				}else{
					$addattackpoint->execute($c->user->id);
					$launchedtarget->execute($c->user->id,$claim->{target},$claim->{wave});
					$mission{warning} = "OK:$claim->{target},$claim->{wave},$claim->{launched}";
					$log->execute($c->user->id,"Gave attack point for confirmation on $mission mission to $x:$y:$z, landing tick $tick");
				}
			}elsif ($mission eq 'Defend'){
				my $call = $findtarget->fetchrow_hashref;
				$informDefChannel->execute($fleet,$call->{id});
			}

			$log->execute($c->user->id,"Pasted confirmation for $mission mission to $x:$y:$z, landing tick $tick");
			push @missions,\%mission;
		}
		$dbh->commit;
		$c->flash(missions => \@missions);
	};
	if ($@){
		$dbh->rollback;
		die $@;
	}

	$c->res->redirect($c->uri_for('launchConfirmation'));
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
