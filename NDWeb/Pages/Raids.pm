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

package NDWeb::Pages::Raids;
use strict;
use warnings;
use ND::Include;
use POSIX;
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{raids} = __PACKAGE__;

sub process {
	my $self = shift;
	$self->{XML} = 1 if param('xml');
}


sub generateClaimXml : method {
	my $self = shift;
	my ($BODY,$raid, $from, $target) = @_;
	my $DBH = $self->{DBH};

	my ($timestamp) = $DBH->selectrow_array("SELECT MAX(modified)::timestamp AS modified FROM raid_targets");
	$BODY->param(Timestamp => $timestamp);
	if ($target){
		$target = "r.id = $target";
		$_ = $self->listTargets;
		$BODY->param(TargetList => $_);
	}else{
		$target = "r.raid = $raid->{id}";
	}

	if ($from){
		$from = "AND modified > '$from'";
	}else{
		$from = '';
	}
	my $targets = $DBH->prepare(qq{SELECT r.id,r.planet FROM raid_targets r WHERE $target $from});
	$targets->execute or print p($DBH->errstr);
	my $claims =  $DBH->prepare(qq{ SELECT username,joinable,launched FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ?});
	my @targets;
	while (my $target = $targets->fetchrow_hashref){
		my %target;
		$target{Id} = $target->{id};
		my @waves;
		for (my $i = 1; $i <= $raid->{waves}; $i++){
			my %wave;
			$wave{Id} = $i;
			$claims->execute($target->{id},$i);
			my $joinable = 0;
			my $claimers;
			if ($claims->rows != 0){
				my $owner = 0;
				my @claimers;
				while (my $claim = $claims->fetchrow_hashref){
					$owner = 1 if ($self->{USER} eq $claim->{username});
					$joinable = 1 if ($claim->{joinable});
					$claim->{username} .= '*' if ($claim->{launched});
					push @claimers,$claim->{username};
				}
				$claimers = join '/', @claimers;
				if ($owner){
					$wave{Command} = 'Unclaim';
				}elsif ($joinable){
					$wave{Command} = 'Join';
				}else{
					$wave{Command} = 'none';
				}
			}else{
				#if (!isset($planet) || ($target->value/$planet->value > 0.4 || $target->score/$planet->score > 0.4))
				$wave{Command} = 'Claim';
			}
			$wave{Claimers} = $claimers;
			$wave{Joinable} = $joinable;
			push @waves,\%wave;
		}
		$target{Waves} = \@waves;
		push @targets,\%target;
	}
	$BODY->param(Targets => \@targets);
	return $BODY;
}

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Raids';
	my $DBH = $self->{DBH};


	my $raid;
	if (defined param('raid')){
		my $query = $DBH->prepare(q{SELECT id,tick,waves,message,released_coords FROM raids WHERE id = ? AND open AND not removed AND id IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)});
		$raid = $DBH->selectrow_hashref($query,undef,param('raid'),$ND::UID);
	}

	if (defined param('cmd') && defined param('target') && defined param('wave') && param('target') =~ /^(\d+)$/ && param('wave') =~ /^(\d+)$/){
		my $target = param('target');
		my $wave = param('wave');

		my $findtarget = $DBH->prepare("SELECT rt.id FROM raid_targets rt NATURAL JOIN raid_access ra NATURAL JOIN groupmembers where uid = ? AND id = ?");
		my $result = $DBH->selectrow_array($findtarget,undef,$ND::UID,$target);
		if ($result != $target){
			return $self->noAccess;	
		}

		$DBH->begin_work;
		if (param('cmd') eq 'Claim'){
			my $claims = $DBH->prepare(qq{SELECT username FROM raid_claims NATURAL JOIN users WHERE target = ? AND wave = ?});
			$claims->execute($target,$wave);
			if ($claims->rows == 0){
				my $query = $DBH->prepare(q{INSERT INTO raid_claims (target,uid,wave) VALUES(?,?,?)});
				if($query->execute($target,$ND::UID,$wave)){
					log_message $ND::UID,"Claimed target $target wave $wave.";
				}
			}
		}
		if (param('cmd') eq 'Join'){
			my $claims = $DBH->prepare(qq{SELECT username FROM raid_claims
				NATURAL JOIN users WHERE target = ? AND wave = ? AND
				joinable = TRUE});
			$claims->execute($target,$wave);
			if ($claims->rows != 0){
				my $query = $DBH->prepare(q{INSERT INTO raid_claims (target,uid,wave,joinable) VALUES(?,?,?,TRUE)});
				if($query->execute($target,$ND::UID,$wave)){
					log_message $ND::UID,"Joined target $target wave $wave.";
				}
			}
		}
		if (param('cmd') eq 'set' && defined param('joinable') && param('joinable') =~ /(TRUE|FALSE)/){
			my $claims = $DBH->prepare(qq{SELECT username FROM raid_claims NATURAL JOIN users WHERE target = ? AND wave = ? AND uid = ?});
			$claims->execute($target,$wave,$ND::UID);
			if ($claims->rows != 0){
				$DBH->do(q{UPDATE raid_claims SET joinable = ? WHERE target = ? AND wave = ?},undef,$1,$target,$wave)
			}
		}
		if (param('cmd') eq 'Unclaim'){
			my $query = $DBH->prepare(qq{DELETE FROM raid_claims WHERE target = ? AND uid = ? AND wave = ?});
			if ($query->execute($target,$ND::UID,$wave)){
				log_message $ND::UID,"Unclaimed target $target wave $wave.";
			}
		}
		$DBH->commit;
		if ($self->{XML} && $raid){
			return $self->generateClaimXml($BODY,$raid,undef,$target);
		}
	}
	if ($self->{XML} && $raid && param('cmd') eq 'update' ){
		my $from;
		if (param('from') =~ /^[-\d\ \:\.]+$/){
			$from = param('from');
		}
		return $self->generateClaimXml($BODY,$raid,$from);
	}
	if ($self->{XML} && param('cmd') eq 'gettargets' ){
		$_ = $self->listTargets();
		$BODY->param(TargetList => $_);
	}

	return $BODY if $self->{XML};

	if ($raid){#We have a raid, so list all targets
		$BODY->param(Raid => $raid->{id});
		$BODY->param(Ajax => $self->{AJAX});
		my $noingal = '';
		my $planet;
		if ($self->{PLANET}){
			my $query = $DBH->prepare("SELECT value, score,x,y FROM current_planet_stats WHERE id = ?");
			$planet = $DBH->selectrow_hashref($query,undef,$self->{PLANET});
			$noingal = "AND NOT (x = $planet->{x} AND y = $planet->{y})";
		}
		$BODY->param(Message => parseMarkup($raid->{message}));
		$BODY->param(LandingTick => $raid->{tick});
		my $targetquery = $DBH->prepare(qq{SELECT r.id, r.planet, size, score, value
			, p.x,p.y,p.z, race
			, p.value - p.size*200 - 
				COALESCE(ps.metal+ps.crystal+ps.eonium,0)/150 - 
				COALESCE(ss.total ,(SELECT
					COALESCE(avg(total),0) FROM
					structure_scans)::int)*1500 AS fleetvalue
			,(metal+crystal+eonium)/100 AS resvalue, comment
			FROM current_planet_stats p 
			JOIN raid_targets r ON p.id = r.planet 
			LEFT OUTER JOIN planet_scans ps ON p.id = ps.planet
			LEFT OUTER JOIN structure_scans ss ON p.id = ss.planet
			WHERE r.raid = ?
			$noingal
			ORDER BY size});
		$targetquery->execute($raid->{id});
		my @targets;
		while (my $target = $targetquery->fetchrow_hashref){
			my %target;
			if ($planet){
				if ($planet->{x} == $target->{x}){
					$target{style} = 'incluster';
				}
				$target{ScoreBash} = 'bash' if ($target->{score}/$planet->{score} < 0.4);
				$target{ValueBash} = 'bash' if ($target->{value}/$planet->{value} < 0.4);
				#next if ($target->{score}/$planet->{score} < 0.4) && ($target->{value}/$planet->{value} < 0.4);
			}
			$target{Id} = $target->{id};
			$target{Race} = $target->{race};
			my $num = pow(10,length($target->{score})-2);
			$target{Score} = "Hidden"; #ceil($target->{score}/$num)*$num;
			$num = pow(10,length($target->{value})-2);
			$target{Value} = "Hidden"; #ceil($target->{value}/$num)*$num;
			$num = pow(10,length($target->{size})-2);
			$target{Size} = floor($target->{size}/$num)*$num;
			$num = pow(10,length($target->{fleetvalue})-2);
			$target{FleetValue} = floor($target->{fleetvalue}/$num)*$num;
			if (defined $target->{resvalue}){
				$num = pow(10,length($target->{resvalue})-2);
				$target{ResValue} = floor($target->{resvalue}/$num)*$num;
			}
			$target{comment} = parseMarkup($target->{comment}) if ($target->{comment});

			my $unitscans = $DBH->prepare(q{ 
				SELECT DISTINCT ON (name) i.id,i.name, i.tick, i.amount 
				FROM fleets i
				WHERE  i.uid = -1
					AND i.sender = ?
					AND i.mission = 'Full fleet'
				GROUP BY i.id,i.tick,i.name,i.amount
				ORDER BY name,i.tick DESC
			});
			$unitscans->execute($target->{planet}) or warn $DBH->errstr;
			my $ships = $DBH->prepare(q{SELECT ship,amount FROM fleet_ships
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
				$mission->{amount} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
				delete $mission->{id};
				push @missions,$mission;
			}
			$target{missions} = \@missions;

			my $query = $DBH->prepare(q{SELECT DISTINCT ON(rid) tick,category,name,amount
				FROM planet_data pd JOIN planet_data_types pdt ON pd.rid = pdt.id
				WHERE pd.id = $1 AND rid in (1,2,3,4,5,6,9,10,14,15,16,17,18)
				ORDER BY rid,tick DESC
			});
			$query->execute($target->{planet});
			while (my $data = $query->fetchrow_hashref){
				$data->{amount} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
				$target{$data->{category}.$data->{name}} = $data->{amount};
			}

			my @roids;
			my @claims;
			my $size = $target{Size};
			for (my $i = 1; $i <= $raid->{waves}; $i++){
				my $roids = floor(0.25*$size);
				$size -= $roids;
				my $xp = 0;
				if ($planet){
					$xp = pa_xp($roids,$planet->{score},$planet->{value},$target->{score},$target->{value});
				}
				push @roids,{Wave => $i, Roids => $roids, XP => $xp};
				if ($self->{AJAX}){
					push @claims,{Wave => $i, Target => $target{Id}}
				}else{
					push @claims,{Wave => $i, Target => $target{Id}, Command => 'Claim'
						, Owner => 1, Raid => $raid->{id}, Joinable => 0};
				}
			}
			$target{Roids} = \@roids;
			$target{Claims} = \@claims;

			push @targets,\%target;
		}
		@targets = sort {$b->{Roids}[0]{XP} <=> $a->{Roids}[0]{XP} or $b->{Size} <=> $a->{Size}} @targets;

		$BODY->param(Targets => \@targets);
	}else{#list raids if we haven't chosen one yet
		my $launched = 0;
		my $query = $DBH->prepare(q{SELECT r.id AS raid,released_coords AS releasedcoords,tick,waves*COUNT(DISTINCT rt.id) AS waves,
				COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched,COUNT(NULLIF(rc.uid > 0,true)) AS blocked
			FROM raids r JOIN raid_targets rt ON r.id = rt.raid
				LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
			WHERE open AND not removed AND r.id 
				IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)
			GROUP BY r.id,released_coords,tick,waves});
		$query->execute($ND::UID);
		my @raids;
		while (my $raid = $query->fetchrow_hashref){
			$raid->{waves} -= $raid->{blocked};
			$raid->{claims} -= $raid->{blocked};
			delete $raid->{blocked};
			$launched += $raid->{launched};
			push @raids,$raid;
		}
		$BODY->param(Raids => \@raids);

		if ($self->isBC){
			$BODY->param(isBC => 1);
			my $query = $DBH->prepare(q{SELECT r.id AS raid,open ,tick,waves*COUNT(DISTINCT rt.id) AS waves,
				COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched ,COUNT(NULLIF(uid > 0,true)) AS blocked
			FROM raids r JOIN raid_targets rt ON r.id = rt.raid
				LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
			WHERE not removed AND (not open 
				OR r.id NOT IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?))
			GROUP BY r.id,open,tick,waves});
			$query->execute($ND::UID);
			my @raids;
			while (my $raid = $query->fetchrow_hashref){
				$raid->{waves} -= $raid->{blocked};
				$raid->{claims} -= $raid->{blocked};
				delete $raid->{blocked};
				$launched += $raid->{launched};
				push @raids,$raid;
			}
			$BODY->param(ClosedRaids => \@raids);


			$query = $DBH->prepare(q{SELECT r.id AS raid,tick,waves*COUNT(DISTINCT rt.id) AS waves,
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
			$BODY->param(RemovedRaids => \@oldraids);
			$BODY->param(Launched => $launched);
		}
	}
	return $BODY;
}
1;
