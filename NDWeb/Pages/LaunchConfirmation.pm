#**************************************************************************
#   Copyright (C) 2006 by Michael Andreen <harvATruinDOTnu>               *
#                                                                         *
#   This program is free software; you can redistribute it and/or modify  *
#   it under the terms of the GNU General Public License as published by  *
#   the Free Software Foundation; either version 2 of the License, or     *
#   (at your option) any later version.                                   *
#                                                                         *
#   This program is distributed in the hope that it will be useful,       *
#   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
#   GNU General Public License for more details.                          *
#                                                                         *
#   You should have received a copy of the GNU General Public License     *
#   along with this program; if not, write to the                         *
#   Free Software Foundation, Inc.,                                       *
#   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.         *
#**************************************************************************/

package NDWeb::Pages::LaunchCoonfirmation;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use NDWeb::Include;
use ND::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{launchConfirmation} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Launch Confirmation';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isMember;

	my $error;


	if (defined param('cmd') && param('cmd') eq 'submit'){
		my $missions = param('mission');
		my $findplanet = $DBH->prepare("SELECT planetid(?,?,?,?)");
		my $findattacktarget = $DBH->prepare(q{SELECT c.target,c.wave,c.launched FROM  raid_claims c
			JOIN raid_targets t ON c.target = t.id
			JOIN raids r ON t.raid = r.id
			WHERE c.uid = ? AND r.tick+c.wave-1 = ? AND t.planet = ?
			AND r.open AND not r.removed});
		my $finddefensetarget = $DBH->prepare(q{SELECT c.id FROM calls c JOIN users u ON c.member = u.uid WHERE u.planet = $1 AND c.landing_tick = $2});
		my $informDefChannel = $DBH->prepare(q{INSERT INTO defense_missions (fleet,call) VALUES (?,?)});
		my $addattackpoint = $DBH->prepare('UPDATE users SET attack_points = attack_points + 1 WHERE uid = ?');
		my $launchedtarget = $DBH->prepare('UPDATE raid_claims SET launched = True WHERE uid = ? AND target = ? AND wave = ?');
		my $addfleet = $DBH->prepare(qq{INSERT INTO fleets (uid,target,mission,landing_tick,fleet,eta,back) VALUES (?,?,?,?,(SELECT max(fleet)+1 from fleets WHERE uid = ?),?,?)});
		my $addships = $DBH->prepare('INSERT INTO fleet_ships (fleet,ship,amount) VALUES (?,?,?)');

		my $fleet = $DBH->prepare("SELECT id FROM fleets WHERE uid = ? AND fleet = 0");
		my ($basefleet) = $DBH->selectrow_array($fleet,undef,$ND::UID) or $ND::ERROR .= p $DBH->errstr;;
		unless ($basefleet){
			my $insert = $DBH->prepare(q{INSERT INTO fleets (uid,target,mission,landing_tick,fleet,eta,back) VALUES (?,?,'Full fleet',0,0,0,0)});
			$insert->execute($ND::UID,$self->{PLANET}) or $ND::ERROR .= p $DBH->errstr;;
		}
		my @missions;
		$DBH->begin_work;
		while ($missions =~ m/\S+\s+(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)\s+\((?:(\d+)\+)?(\d+)\).*?(?:\d+hrs\s+)?\d+mins?\s+(Attack|Defend|Return|Fake Attack|Fake Defend)(.*?)(?:Launching in tick (\d+), arrival in tick (\d+)|ETA: \d+, Return ETA: (\d+)|Return ETA: (\d+))/sg){
			my %mission;
			next if $9 eq 'Return';

			my $tick = $self->{TICK}+$8;
			$tick += $7 if defined $7;
			my $eta = $8;
			my $mission = $9;
			my $x = $4;
			my $y = $5;
			my $z = $6;
			if ($12){
				$tick = $12;
			}elsif ($13){
				$eta += $13;
			}
			$mission{Tick} = $tick;
			$mission{Mission} = $mission;
			$mission{Target} = "$x:$y:$z";

			my ($planet_id) = $DBH->selectrow_array($findplanet,undef,$x,$y,$z,$self->{TICK});

			my $findtarget = $finddefensetarget;
			if ($mission eq 'Attack'){
				$findtarget = $findattacktarget;
				$findtarget->execute($ND::UID,$tick,$planet_id) or $ND::ERROR .= p $DBH->errstr;;
			}elsif ($mission eq 'Defend'){
				$findtarget = $finddefensetarget;
				$findtarget->execute($planet_id,$tick) or $ND::ERROR .= p $DBH->errstr;;
			}

			$addfleet->execute($ND::UID,$planet_id,$mission,$tick,$ND::UID,$eta,$tick+$eta-1) or $error .= '<p>'.$DBH->errstr.'</p>';
			my $fleet = $DBH->last_insert_id(undef,undef,undef,undef,"fleets_id_seq");
			$mission{Fleet} = $fleet;
			$mission{Back} = $tick+$eta-1;
			my $ships = $10;
			my @ships;
			while ($ships =~ m/((?:\w+ )*\w+)\s+\w+\s+(?:(?:\w+|-)\s+){3}(?:Steal|Normal|Emp|Normal\s+Cloaked|Pod|Struc)\s+(\d+)/g){
				$addships->execute($fleet,$1,$2) or $ND::ERROR .= p $DBH->errstr;
				push @ships,{Ship => $1, Amount => $2};
			}
			$mission{Ships} = \@ships;

			if ($findtarget->rows == 0){
				$mission{Warning} = p b 'No matching target!';
			}elsif ($mission eq 'Attack'){
				my $claim = $findtarget->fetchrow_hashref;
				if ($claim->{launched}){
					$mission{Warning} = "Already launched on this target:$claim->{target},$claim->{wave},$claim->{launched}";
				}else{
					$addattackpoint->execute($ND::UID) or $ND::ERROR .= p $DBH->errstr;
					$launchedtarget->execute($ND::UID,$claim->{target},$claim->{wave}) or $ND::ERROR .= p $DBH->errstr;
					$mission{Warning} = "OK:$claim->{target},$claim->{wave},$claim->{launched}";
					log_message $ND::UID,"Gave attack point for confirmation on $mission mission to $x:$y:$z, landing tick $tick";
				}
			}elsif ($mission eq 'Defend'){
				my $call = $findtarget->fetchrow_hashref;
				$informDefChannel->execute($fleet,$call->{id}) or $ND::ERROR .= p $DBH->errstr;
			}

			log_message $ND::UID,"Pasted confirmation for $mission mission to $x:$y:$z, landing tick $tick";
			push @missions,\%mission;
		}
		$DBH->commit or $error .= '<p>'.$DBH->errstr.'</p>';
		$BODY->param(Missions => \@missions);
	}
	$BODY->param(Error => $error);
	return $BODY;
}


1;
