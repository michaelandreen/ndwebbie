package NDWeb::Controller::Members;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

NDWeb::Controller::Members - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub points : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if ($order =~ /^((?:defense|attack|total|humor|scan|raid)_points)$/){
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
		while ($missions =~ m/([^\n]+)\s+(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)
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
