package NDWeb::Controller::Members;

use strict;
use warnings;
use feature ":5.10";
use Try::Tiny;
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

	$c->stash(u => $dbh->selectrow_hashref(q{SELECT pid AS planet,defense_points
			,attack_points,scan_points,humor_points
			, (attack_points+defense_points+scan_points/20)::NUMERIC(5,1) as total_points
			, sms,rank,hostmask,call_if_needed,sms_note,defprio
		FROM users_defprio WHERE uid = ?
			},undef,$c->user->id)
	);

	$c->stash(groups => $dbh->selectrow_array(q{SELECT array_agg(groupname)
		FROM groups g NATURAL JOIN groupmembers gm
		WHERE uid = $1
			},undef,$c->user->id)
	);

	$c->stash(p => $dbh->selectrow_hashref(q{SELECT pid AS id,x,y,z, ruler, planet,race,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day
		from current_planet_stats_full p
			WHERE pid = ?
			},undef,$c->user->planet)
	);

	my $calls = $dbh->prepare(q{
SELECT * FROM defcalls
WHERE uid = $1 AND landing_tick >= tick()
ORDER BY landing_tick DESC
		});
	$calls->execute($c->user->id);
	$c->stash(calls => $calls->fetchall_arrayref({}) );

	$c->stash(fleets => member_fleets($dbh, $c->user->id,$c->user->planet));

	my $announcements = $dbh->prepare(q{SELECT ft.ftid, u.username,ft.subject,
		count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts,
		date_trunc('seconds',max(fp.time)::timestamp) as last_post,
		min(fp.time)::date as posting_date, ft.sticky
		FROM forum_threads ft JOIN forum_posts fp USING (ftid)
			JOIN users u ON u.uid = ft.uid
			LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1) ftv ON ftv.ftid = ft.ftid
		WHERE ft.fbid = 1
		GROUP BY ft.ftid, ft.subject,ft.sticky,u.username
		HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= 1
		ORDER BY sticky DESC,last_post DESC
		});
	$announcements->execute($c->user->id);
	$c->stash(announcements => $announcements->fetchall_arrayref({}) );

	my ($attackgroups) = $dbh->selectrow_array(q{
SELECT array_agg(gid) FROM groupmembers WHERE gid IN ('x','y','z') AND uid = $1
		}, undef, $c->user->id);
	$c->stash(attackgroups => $attackgroups);

}

sub posthostupdate : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $hostname = html_escape $c->req->param('hostname');
	$dbh->do(q{UPDATE users SET hostmask = ? WHERE uid = ?
		},undef, $hostname, $c->user->id);

	$c->res->redirect($c->uri_for(''));
}

sub postattackgroups : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my @groups = $c->req->param('class');
	$dbh->do(q{DELETE FROM groupmembers WHERE gid IN ('x','y','z') AND gid <> ALL($1) AND uid = $2
		},undef, \@groups, $c->user->id);

	$dbh->do(q{INSERT INTO groupmembers (uid,gid) (
		SELECT $2, gid FROM unnest($1::text[]) AS gid WHERE gid IN ('x','y','z')
	EXCEPT
		SELECT uid,gid FROM groupmembers WHERE uid = $2
		)},undef, \@groups, $c->user->id);

	$c->res->redirect($c->uri_for(''));
}

sub postsmsupdate : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $callme = $c->req->param('callme') || 0;
	my $sms = html_escape $c->req->param('sms');
	my $smsnote = $c->req->param('smsnote');
	$dbh->do(q{
UPDATE users SET sms = $1, call_if_needed =  $2, sms_note = $3 WHERE uid = $4
		},undef, $sms, $callme, $smsnote, $c->user->id);

	$c->res->redirect($c->uri_for(''));
}

sub postowncoords : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	if ($c->user->planet){
		$c->flash(error => 'You already have a planet set.'
			.' Contact a HC if they need to be changed');
	}elsif (my ($x,$y,$z) = $c->req->param('planet') =~ m/(\d+)\D+(\d+)\D+(\d+)/){
		my $planet = $dbh->selectrow_array(q{SELECT planetid($1,$2,$3,TICK())
			},undef,$x,$y,$z);

		if ($planet){
			eval {
				$dbh->do(q{UPDATE users SET pid = ? WHERE uid = ?
					},undef, $planet , $c->user->id);
			};
			given ($@){
				when (''){}
				when (/duplicate key value violates/){
					$c->flash(error => "The coords $x:$y:$z are already in use. Talk to hc if these are really your coords.")
				}
				default {
					$c->flash(error => $@)
				}
			}
		}else{
			$c->flash(error => "No planet at coords: $x:$y:$z");
		}
	}else{
		my $error = $c->req->param('planet') . " are not valid coords.";
		$c->flash(error => $error);
	}

	$c->res->redirect($c->uri_for('/'.$c->session->{referrer}));
}

sub postfleetsupdates : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)
		});
	$dbh->begin_work;
	if ($c->req->param('cmd') eq 'Recall Fleets'){
		my $updatefleets = $dbh->prepare(q{UPDATE launch_confirmations
			SET back = tick() + (tick() - (landing_tick - eta))
			WHERE uid = ? AND fid = ? AND back >= tick()+eta
		});

		for my $param ($c->req->param()){
			if ($param =~ /^change:(\d+)$/){
				$updatefleets->execute($c->user->id,$1);
				$log->execute($c->user->id,"Member recalled fleet $1");
			}
		}
	}elsif ($c->req->param('cmd') eq 'Change Fleets'){
		my $updatefleets = $dbh->prepare(q{UPDATE launch_confirmations
			SET back = ? WHERE uid = ? AND fid = ?});

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
	$c->stash(channels => ['scan','members','def']);
}

sub postircrequest : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $message = $c->req->param('message');
	if ($c->req->param('channel')){
		my $query = $dbh->prepare(q{
INSERT INTO irc_requests (uid,channel,message) VALUES($1,$2,$3)
		});
		my $channel = $c->user->id,$c->req->param('channel');
		$query->execute($channel, $message);
		$c->signal_bots;

		$c->flash(reply => "Msg sent to: ".$channel);
		$c->res->redirect($c->uri_for('ircrequest'));
	}else{
		$c->stash(ircmessage => $message);
		$c->go('ircrequest');
	}
}

sub points : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	$order //= 'total_points';
	if ($order ~~ /^((?:defense|attack|total|humor|scan|raid)_points)$/
			|| $order ~~ /^(defprio)$/){
		$order = "$1 DESC";
	}else{
		$order = 'total_points DESC';
	}

	my $limit = 'LIMIT 10';
	$limit = '' if $c->check_user_roles(qw/members_points_nolimit/);

	my $query = $dbh->prepare(q{
SELECT username,defense_points,attack_points
	,scan_points,humor_points,defprio
	,(attack_points+defense_points+scan_points/20)::NUMERIC(4,0) as total_points
	, count(NULLIF(rc.launched,FALSE)) AS raid_points
FROM users_defprio u LEFT OUTER JOIN raid_claims rc USING (uid)
WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = 'M')
GROUP BY username,defense_points,attack_points,scan_points,humor_points,defprio
ORDER BY } . "$order $limit"
	);
	$query->execute;
	$c->stash(members => $query->fetchall_arrayref({}));
}

sub stats : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	$order //= 'score';
	if ($order ~~ /^(scre|value|xp|size|race)$/){
		$order = "$1rank";
	}else{
		$order = 'scorerank';
	}
	$order .= ',race' if $order eq 'racerank';

	my $limit = 'LIMIT 10';
	$limit = '' if $c->check_user_roles(qw/members_points_nolimit/);

	my ($races) = $dbh->selectrow_array(q{SELECT enum_range(null::race)::text[]});
	$c->stash(races => $races);
	my $query = $dbh->prepare(q{
SELECT nick
	,rank() OVER(ORDER BY score DESC) AS scorerank
	,rank() OVER(ORDER BY value DESC) AS valuerank
	,rank() OVER(ORDER BY xp DESC) AS xprank
	,rank() OVER(ORDER BY size DESC) AS sizerank
	,rank() OVER(PARTITION BY race ORDER BY score DESC) AS racerank
	,race
FROM current_planet_stats
WHERE alliance = 'NewDawn'
	AND race = ANY($1)
ORDER BY } . "$order $limit");
	my @race = $c->req->param('race');
	my %race = map { $_ => 1 } @race;
	$c->stash(race => \%race);
	unless (@race){
		@race = @$races;
	}
	$query->execute(\@race);
	$c->stash(members => $query->fetchall_arrayref({}));
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

	my ($coords,$tick) = $c->model->selectrow_array(q{
SELECT coords(x,y,z), tick() FROM current_planet_stats WHERE pid = $1
		}, undef, $c->user->planet);

	my $message = "[i]Posted by $coords at tick $tick [/i]\n\n" . $c->req->param('message');
	$c->req->param(message => $message);
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
		WHERE scan_id = LOWER(?) AND tick >= tick() - 168 AND groupscan = ?
		});
	my $addscan = $dbh->prepare(q{INSERT INTO scans (scan_id,tick,uid,groupscan)
		VALUES (LOWER(?),tick(),?,?)
		});
	my $addpoint = $dbh->prepare(q{UPDATE users SET scan_points = scan_points + 1
		WHERE uid = ?
		});
	my @scans;
	my $intel = $c->req->param('message');
	while ($intel =~ m{https?://[\w.]+/.+?scan(_id|_grp)?=(\w+)}g){
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
	my $addintel = $dbh->prepare(q{INSERT INTO intel
		(name,mission,tick,target,sender,eta,amount,ingal,back,uid)
		VALUES($1,$2,$3,planetid($4,$5,$6,$10),planetid($7,$8,$9,$10)
			,$11,$12,$13,$14,$15)
	});
	my @intel;
	while ($intel =~ m/(\d+):(\d+):(\d+)\*?\s+(\d+):(\d+):(\d+)
		\*?\s+(A|D)\s+(.+?)\s+(?:(?:Ter|Cat|Xan|Zik|Etd)\s+)?(\d+)\s+(\d+)/gx){
		my $ingal = ($1 == $4 && $2 == $5) || 0;
		my $lt = $tick + $10;
		my $back = ($ingal ? $lt + 4 : undef);
		my $mission = $7 eq 'A' ? 'Attack' : 'Defend';
		eval {
			$addintel->execute($8,$mission,$lt,$1,$2,$3,$4,$5,$6,$tick,$10,$9
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

sub addincs : Local {
	my ( $self, $c ) = @_;
	$c->stash(incs => $c->flash->{incs});

}

sub postincs : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my @incs;

	my $user = $dbh->prepare(q{
SELECT uid FROM users u
WHERE pid = planetid($1,$2,$3,tick())
	AND uid IN (SELECT uid FROM groupmembers WHERE gid = 'M')
		});
	my $call = $dbh->prepare(q{
SELECT call
FROM calls WHERE uid = $1 AND landing_tick = tick() + $2
		});
	my $fleet = $dbh->prepare(q{
SELECT pid
FROM incomings i
WHERE pid = planetid($1,$2,$3,tick()) AND amount = $4 and fleet = $5 AND call = $6
		});
	my $irc = $dbh->prepare(q{
INSERT INTO irc_requests (uid,channel,message) VALUES($1,'def',$2)
		});

	my $msg = $c->req->param('message');
	while ($msg =~ m/(\d+):(\d+):(\d+)\*?\s+(\d+):(\d+):(\d+)\*?\s+A\s+(.+?)\s+(Ter|Cat|Xan|Zik|Etd)\s+(\d+)\s+(\d+)/gc
			||$msg =~ /expand\s+(\d+):(\d+):(\d+)\*?\s+(\d+):(\d+):(\d+)\s+([^:]*\S+)\s+(Ter|Cat|Xan|Zik|Etd)\s+([\d,]+)\s+(\d+)/gc
			|| $msg =~ /(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)\s+\((Ter|Cat|Xan|Zik|Etd)\)\s+([^,]*\S+)\s+([\d,]+)\s+(\d+)\s+\(\d+\)/gc){

		my $inc = {message => $&};
		my $amount = $9;
		{
			$amount =~ s/,//g;
		}
		try {
			my $uid = $dbh->selectrow_array($user,undef,$1,$2,$3);
			die '<i>No user with these coords</i>' unless $uid;

			my $call = $dbh->selectrow_array($call,undef,$uid,$10);
			if ($call){
				my $pid = $dbh->selectrow_hashref($fleet,undef,$4,$5,$6,$amount,$7,$call);
				die '<i>Duplicate</i>' if $pid;

			}

			my $message = "$1:$2:$3 $4:$5:$6 $7 $8 $amount $10";
			$irc->execute($c->user->id, $message);
			$inc->{status} = '<b>Added</b>';

		} catch {
			when (m(^(<i>.*</i>) at )){
				$inc->{status} = $1;
			}
			default {
				$inc->{status} = $_;
			}
		};
		push @incs, $inc;
	}

	$c->signal_bots if @incs;
	$c->flash(incs => \@incs);
	$c->res->redirect($c->uri_for('addincs'));
}

sub launchConfirmation : Local {
	my ( $self, $c ) = @_;

	$c->stash(error => $c->flash->{error});
	$c->stash(missions => $c->flash->{missions});
}

sub postconfirmation : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	try {
		my $findplanet = $dbh->prepare(q{SELECT planetid(?,?,?,tick())});
		my $addfleet = $dbh->prepare(q{INSERT INTO fleets
			(name,mission,pid,tick,amount)
			VALUES ($2,$3,(SELECT pid FROM users WHERE uid = $1),tick(),$4)
			RETURNING fid
			});
		my $updatefleet = $dbh->prepare(q{
UPDATE launch_confirmations SET back = $2 WHERE fid = $1
			});
		my $addconfirmation = $dbh->prepare(q{INSERT INTO launch_confirmations
			(fid,uid,pid,landing_tick,eta,back,num) VALUES ($1,$2,$3,$4,$5,$6,$7)
			});
		my $addships = $dbh->prepare(q{INSERT INTO fleet_ships (fid,ship,amount)
			VALUES (?,?,?)
			});
		my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
			(SELECT ftid FROM users WHERE uid = $1),$1,$2)
			});
		my $return = $dbh->prepare(q{
UPDATE launch_confirmations SET back = tick()
WHERE uid = $1 AND num = $2 AND back > tick()
			});
		my $fullfleet = $dbh->prepare(q{INSERT INTO full_fleets
					(fid,uid) VALUES (?,?)});
		$dbh->begin_work;
		my $mission = $c->req->param('mission');
		my @missions = parseconfirmations($mission, $c->stash->{TICK});
		for my $m (@missions){
			if ($m->{mission} eq 'Return'){
				$c->forward("addReturnFleet", [$m]);
				if($m->{fid}){
					$updatefleet->execute($m->{fid},$m->{back});
					next;
				}else{
					$m->{pid} = $c->user->planet;
				}
			}elsif ($m->{target} ~~ /^(\d+):(\d+):(\d+)$/) {
				$m->{pid} = $dbh->selectrow_array($findplanet,undef,$1,$2,$3);
				unless ($m->{pid}){
					$m->{warning} = "No planet at $m->{target}, try again next tick.";
					next;
				}
			}

			#Recall fleets with same slot number
			$return->execute($c->user->id,$m->{num});

			unless ($m->{mission}){
				$m->{warning} = "Not on a mission, but matching fleets recalled";
				next;
			}

			$c->forward("findDuplicateFleet", [$m]);
			if ($m->{match}){
				$m->{warning} = "Already confirmed this fleet, updating changed information";
				$updatefleet->execute($m->{fid},$m->{back}) if $m->{pid};
				next;
			}


			$m->{fleet} = $dbh->selectrow_array($addfleet,undef,$c->user->id,$m->{name}
				,$m->{mission},$m->{amount});

			if ($m->{mission} eq 'Full fleet'){
				$fullfleet->execute($m->{fleet},$c->user->id);
			}else{
				$addconfirmation->execute($m->{fleet},$c->user->id,$m->{pid},$m->{tick},$m->{eta},$m->{back},$m->{num});
			}

			if ($m->{mission} eq 'Attack'){
				$c->forward("addAttackFleet", [$m]);
			}elsif ($m->{mission} eq 'Defend'){
				$c->forward("addDefendFleet", [$m]);
			}

			for my $ship (@{$m->{ships}}){
				$addships->execute($m->{fleet},$ship->{ship},$ship->{amount});
			}
			$log->execute($c->user->id,"Pasted confirmation for $m->{mission} mission to $m->{target}, landing tick $m->{tick}");
		}
		$c->flash(missions => \@missions);
		$dbh->commit;
		$c->signal_bots;
	} catch {
		$dbh->rollback;
		when (/insert or update on table "fleet_ships" violates foreign key constraint "fleet_ships_ship_fkey"\s+DETAIL:\s+Key \(ship\)=\(([^)]+)\)/){
			$c->flash( error => "'$1' is NOT a valid ship");
		}
		default{
			$c->flash( error => $_);
		}
	};
	$c->res->redirect($c->uri_for('launchConfirmation'));
}

sub parseconfirmations {
	my ( $missions, $tick ) = @_;
	return unless $missions;
	my @slots;
	$missions =~ s/\s?,\s?//g;
	$missions =~ s/\s*([:+])\s*/$1/g;
	$missions =~ s/\(\s/(/g;
	$missions =~ s/\s\)/)/g;
	my $returnetare = qr/(\d+) \s+
		Arrival:\s*(\d+)/sx;
	my $missionetare = qr/\s* (\d+ \+ \s*)? (\d+) \s+
		Arrival:\s*(\d+) \s+
		\QReturn ETA:\E\s*(?:(?<eta>Instant) \s+ Cancel \s+ Order
			| (?<eta>\d+) \s+ Ticks \s+ Recall \s+ Fleet)/sx;
	my $etare = qr/(Galaxy:\d+Universe:\d+(?:Alliance:\d+)?
		|$missionetare
		|$returnetare)\s*/x;
	my $missre = qr/((?:Alliance\ Standby)|(?:(?:Fake\ )?\w+))\s*/x;
	if ($missions =~ m/
		Ships \s+ Cla \s+ T\s?1 \s+ T\s?2 \s+ T\s?3 \s+ ETA \s+ Base \s+ \(i\) \s (?<name>.+?) \s+ \(i\) \s+ (?<name>.+?) \s+ \(i\) \s+ (?<name>.+?) \s+ \(i\) \s+ TOTAL \s+
		(?<ships>.+?)
		\QTotal Ships in Fleet\E \s+ (\d+) \s+ (?<amount>\d+) \s+ (?<amount>\d+) \s+ (?<amount>\d+) \s+
		Mission: \s* (?<missions>(?:$missre)*)  \s*
		Target: \s* (?<targets>((\d+:\d+:\d+)?\s)*) \s*
		\QLaunch Tick:\E \s* (?<lts>(\d+\s+)*) \s*
		ETA: \s* (?<etas>(?:$etare)*)
		/sx){
		my %match = %-;
		my @targets = split /\s+/, $+{targets};
		my @lts = split /\s+/, $+{lts};
		my @etas;
		local $_ = $+{etas};
		while(/$etare/sxg){
			push @etas, $1;
		}
		my @missions ;
		$_ = $+{missions};
		while(/$missre/sxg){
			push @missions, $1;
		}
		for my $i (0..2){
			my %mission = (
				name => $match{name}->[$i],
				mission => '' ,
				amount => $match{amount}->[$i],
				num => $i,
				ships => []
			);
			if ($mission{amount} == 0){
				push @slots,\%mission;
				next;
			}

			if ($missions[0] eq 'Alliance Standby'){
				shift @missions;
				push @slots,\%mission;
				next;
			}

			given(shift @etas){
				when(/$missionetare/sx){
					$mission{tick} = $3;
					$mission{eta} = $2 + $+{eta};
					$mission{back} = $3 + $mission{eta} - 1;
					$mission{target} = shift @targets;
					$mission{lt} = shift @lts;
					$mission{mission} = shift @missions;
				}
				when(/$returnetare/sx){
					$mission{tick} = $2;
					$mission{eta} = $1;
					$mission{back} = $2;
					$mission{target} = shift @targets;
					$mission{lt} = shift @lts;
					$mission{mission} = shift @missions;
					die "Did you forget some at the end? '$mission{mission}'" if $mission{mission} ne 'Return';
				}
			}
			push @slots,\%mission;
		}
		push @slots,{
			name => 'Main',
			num => 3,
			mission => 'Full fleet',
			tick => $tick,
			amount => 0,
			ships => []
		};
		while ($match{ships}->[0] =~ m/(\w[ \w]+?)\s+(FI|CO|FR|DE|CR|BS|--)[^\d]+\d+\s+((?:\d+\s*){5})/g){
			my $ship = $1;
			my @amounts = split /\D+/, $3;
			my $base = shift @amounts;
			die "Ships don't sum up properly" if $amounts[3] != $base + $amounts[0] + $amounts[1] + $amounts[2];
			for my $i (0..3){
				push @{$slots[$i]->{ships}},{ship => $ship, amount => $amounts[$i]} if $amounts[$i] > 0;
			}
			$slots[3]->{amount} += $amounts[3];
		}
	}
	return @slots;
}

sub findDuplicateFleet : Private {
	my ( $self, $c, $m ) = @_;
	my $dbh = $c->model;

	my $findfleet = $dbh->prepare(q{
SELECT fid FROM fleets f
	LEFT JOIN launch_confirmations lc USING (fid)
WHERE f.pid = (SELECT pid FROM users WHERE uid = $1)
	AND mission = $3 AND amount = $4 AND (mission <> 'Full fleet' OR tick > $6 - 6)
	AND COALESCE(uid = $1 AND num = $2 AND lc.pid = $5 AND landing_tick = $6, TRUE)
		});
	my $fid = $dbh->selectrow_array($findfleet,undef,$c->user->id,$m->{num}
		,$m->{mission},$m->{amount}, $m->{pid}, $m->{tick});
	$c->forward("matchShips", [$m,$fid]);
	$m->{fid} = $fid if $m->{match};
}

sub addAttackFleet : Private {
	my ( $self, $c, $m ) = @_;
	my $dbh = $c->model;

	my $findattacktarget = $dbh->prepare(q{
SELECT c.target,c.wave,c.launched
FROM  raid_claims c
	JOIN raid_targets t ON c.target = t.id
	JOIN raids r ON t.raid = r.id
WHERE c.uid = ? AND r.tick+c.wave-1 = ? AND t.pid = ?
	AND r.open AND not r.removed
		});
	my $launchedtarget = $dbh->prepare(q{
UPDATE raid_claims SET launched = TRUE
WHERE uid = ? AND target = ? AND wave = ?
		});
	my $claim = $dbh->selectrow_hashref($findattacktarget,undef,$c->user->id,$m->{tick},$m->{pid});
	if ($claim->{launched}){
		$m->{warning} = "Already launched on this target:$claim->{target},$claim->{wave},$claim->{launched}";
	}elsif(defined $claim->{launched}){
		$launchedtarget->execute($c->user->id,$claim->{target},$claim->{wave});
		$m->{warning} = "OK:$claim->{target},$claim->{wave},$claim->{launched}";
	}else{
		$m->{warning} = "You haven't claimed this target";
	}
}

sub addDefendFleet : Private {
	my ( $self, $c, $m ) = @_;
	my $dbh = $c->model;

	my $finddefensetarget = $dbh->prepare(q{
SELECT call FROM calls c
	JOIN users u USING (uid)
WHERE u.pid = $1 AND c.landing_tick = $2
	});
	my $informDefChannel = $dbh->prepare(q{
INSERT INTO defense_missions (fleet,call) VALUES (?,?)
		});
	my $call = $dbh->selectrow_hashref($finddefensetarget,undef,$m->{pid},$m->{tick});
	if ($call->{call}){
		$informDefChannel->execute($m->{fleet},$call->{call});
	}else{
		$m->{warning} = "No call for $m->{target} landing tick $m->{tick}";
	}
}

sub addReturnFleet : Private {
	my ( $self, $c, $m ) = @_;
	my $dbh = $c->model;

	my $findfleet = $dbh->prepare(q{
SELECT fid FROM fleets f
	JOIN launch_confirmations lc USING (fid)
WHERE uid = $1 AND num = $2  AND amount = $3
	AND back >= $4
		});
	my $fid = $dbh->selectrow_array($findfleet,undef,$c->user->id,$m->{num}
		,$m->{amount}, $m->{tick});
	$c->forward("matchShips", [$m,$fid]);
	if ($m->{match}){
		$m->{fid} = $fid;
		$m->{warning} = "Return fleet, changed back tick to match the return eta.";
	} else {
		$m->{warning} = "Couldn't find a fleet matching this returning fleet, so adding a new fleet that is returning";
	}
}

sub matchShips : Private {
	my ( $self, $c, $m, $fid ) = @_;
	return unless $fid;
	my $dbh = $c->model;

	my $ships = $dbh->prepare(q{
SELECT ship, amount FROM fleet_ships WHERE fid = $1 ORDER BY num
		});
	$ships->execute($fid);
	for my $s (@{$m->{ships}}){
		my $s2 = $ships->fetchrow_hashref;
		return unless $s->{ship} eq $s2->{ship} && $s->{amount} == $s2->{amount};
	}
	$m->{match} = 1;

}

sub defenders : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	my $defenders = $dbh->prepare(q{
SELECT uid,pid AS planet,username, to_char(NOW() AT TIME ZONE timezone,'HH24:MI') AS time
	,sms_note, call_if_needed, race, timezone
FROM users u
	JOIN current_planet_stats p USING (pid)
WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = 'M')
ORDER BY call_if_needed DESC, username
		});
	$defenders->execute;

	my $available = $dbh->prepare(q{
SELECT ship,amount FROM available_ships WHERE pid = $1
		});

	my @members;
	while (my $member = $defenders->fetchrow_hashref){

		$member->{fleets} = member_fleets($dbh, $member->{uid}, $member->{planet});
		$available->execute($member->{planet});
		my $fleet = {fid => $member->{username}, mission => 'Available', name => 'At home'
			, ships => $available->fetchall_arrayref({})
		};
		push @{$member->{fleets}}, $fleet;
		push @members,$member;
	}
	$c->stash(members => \@members);
}

sub member_fleets {
	my ( $dbh, $uid, $planet ) = @_;

	my $query = $dbh->prepare(q{
(
	SELECT DISTINCT ON (mission,name) fid,name,tick, NULL AS eta
		,amount, NULL AS coords, pid AS target, NULL AS back
		,NULL AS recalled, mission
	FROM fleets f
	WHERE pid = $2 AND tick <= tick() AND tick >= tick() -  24
		AND name IN ('Main','Advanced Unit') AND mission = 'Full fleet'
	ORDER BY mission,name,tick DESC, fid DESC
) UNION (
	SELECT fid,name,landing_tick AS tick, eta, amount
		, coords(x,y,z), lc.pid AS target, back
		, (back <> landing_tick + eta - 1) AS recalled
		,CASE WHEN landing_tick <= tick() OR (back <> landing_tick + eta - 1)
			THEN 'Returning' ELSE mission END AS mission
	FROM  launch_confirmations lc
		LEFT OUTER JOIN current_planet_stats t USING (pid)
		JOIN fleets f USING (fid)
	WHERE uid = $1 AND f.pid = $2 AND back > tick()
		AND landing_tick - eta - 12 < tick()
)
		});

	my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
		WHERE fid = ? ORDER BY num
		});

	$query->execute($uid,$planet);
	my @fleets;
	while (my $fleet = $query->fetchrow_hashref){
		my @ships;
		$ships->execute($fleet->{fid});
		while (my $ship = $ships->fetchrow_hashref){
			push @ships,$ship;
		}
		$fleet->{ships} = \@ships;
		push @fleets,$fleet;
	}
	return \@fleets;
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
