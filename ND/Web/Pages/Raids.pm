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

package ND::Web::Pages::Raids;
use strict;
use warnings FATAL => 'all';
use ND::Include;
use POSIX;
use CGI qw/:standard/;
use ND::Web::Include;

use base qw/ND::Web::XMLPage/;

$ND::Web::Page::PAGES{raids} = __PACKAGE__;

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
		$target{Coords} = $target->{id};
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
					if ($raid->{released_coords}){
						$target{Coords} = $DBH->selectrow_array('SELECT coords(x,y,z) FROM current_planet_stats WHERE id = ?',undef,$target->{planet});
					}
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
		$_ = listTargets();
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
		my $targetquery = $DBH->prepare(qq{SELECT r.id, r.planet, size, score, value, p.x,p.y,p.z, race, p.value - p.size*200 -coalesce(c.metal+c.crystal+c.eonium,0)/150 - coalesce(c.structures,(SELECT avg(structures) FROM covop_targets)::int)*1500 AS fleetvalue,(c.metal+c.crystal+c.eonium)/100 AS resvalue, comment
			FROM current_planet_stats p 
			JOIN raid_targets r ON p.id = r.planet 
			LEFT OUTER JOIN covop_targets c ON p.id = c.planet
			WHERE r.raid = ?
			$noingal
			ORDER BY size});
		$targetquery->execute($raid->{id});
		my @targets;
		while (my $target = $targetquery->fetchrow_hashref){
			my %target;
			$target{Id} = $target->{id};
			$target{Race} = $target->{race};
			my $num = pow(10,length($target->{score})-2);
			$target{Score} = ceil($target->{score}/$num)*$num;
			$num = pow(10,length($target->{value})-2);
			$target{Value} = ceil($target->{value}/$num)*$num;
			$num = pow(10,length($target->{size})-2);
			$target{Size} = floor($target->{size}/$num)*$num;
			$num = pow(10,length($target->{fleetvalue})-2);
			$target{FleetValue} = floor($target->{fleetvalue}/$num)*$num;
			if (defined $target->{resvalue}){
				$num = pow(10,length($target->{resvalue})-2);
				$target{ResValue} = floor($target->{resvalue}/$num)*$num;
			}
			$target{comment} = parseMarkup($target->{comment}) if ($target->{comment});

			my $scans = $DBH->prepare(q{SELECT DISTINCT ON (type) type, tick, scan FROM scans 
				WHERE planet = ? AND type ~ 'Unit|Planet|Military|.* Analysis' AND tick + 24 > tick()
				GROUP BY type, tick, scan ORDER BY type ,tick DESC});
			$scans->execute($target->{planet});
			my %scans;
			while (my $scan = $scans->fetchrow_hashref){
				$scans{$scan->{type}} = $scan;
			}

			my @scans;
			for my $type ('Planet','Unit','Military','Surface Analysis','Technology Analysis'){
				next unless exists $scans{$type};
				my $scan = $scans{$type};
				if ($self->{TICK} - $scan->{tick} > 5){
					$scan->{scan} =~ s{<table( cellpadding="\d+")?>}{<table$1 class="old">};
				}
				if ($type eq 'Planet'){
					$target{PlanetScan} = $scan->{scan};
					next;
				}
				push @scans,{Scan => $scan->{scan}};
			}
			$target{Scans} = \@scans;

			if ($planet){
				if ($planet->{x} == $target->{x}){
					$target{style} = 'incluster';
				}
			}

			my @roids;
			my @claims;
			my $size = $target{Size};
			for (my $i = 1; $i <= $raid->{waves}; $i++){
				my $roids = floor(0.25*$size);
				$size -= $roids;
				my $xp;
				if ($planet){
					$xp = max(0,floor($roids * 10 * (min(2,$target{Score}/$planet->{score}) + min(2,$target{Value}/$planet->{value})-1)));
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
		my $query = $DBH->prepare(q{SELECT id,released_coords FROM raids WHERE open AND not removed AND
			id IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)});
		$query->execute($ND::UID);
		my @raids;
		while (my $raid = $query->fetchrow_hashref){
			push @raids,{Raid => $raid->{id}, ReleasedCoords => $raid->{released_coords}};
		}
		$BODY->param(Raids => \@raids);

		if ($self->isBC){
			$BODY->param(isBC => 1);
			my $query = $DBH->prepare(q{SELECT id,open FROM raids WHERE not removed AND (not open 
				OR id NOT IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?))});
			$query->execute($ND::UID);
			my @raids;
			while (my $raid = $query->fetchrow_hashref){
				push @raids,{Raid => $raid->{id}, Open => $raid->{open}};
			}
			$BODY->param(ClosedRaids => \@raids);
		}
	}
	return $BODY;
}
1;
