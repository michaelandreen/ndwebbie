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

package ND::Web::Pages::Check;
use strict;
use warnings FATAL => 'all';
no warnings qw(uninitialized);
use ND::Include;
use CGI qw/:standard/;
use ND::Web::Include;

our @ISA = qw/ND::Web::XMLPage/;

$ND::Web::Page::PAGES{check} = __PACKAGE__;

sub parse {
	my $self = shift;
	if ($self->{URI} =~ m{^/.*/((\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?(?: |:(\d+))?)$}){
		param('coords',$1);
	}
}

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Check planets and galaxies';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->{ATTACKER};

	$BODY->param(isBC => $self->isMember && ($self->isOfficer || $self->isBC));

	my ($x,$y,$z);
	if (param('coords') =~ /(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?(?: |:(\d+))?/){
		$x = $1;
		$y = $2;
		$z = $3;
		$BODY->param(Coords => "$x:$y".(defined $z ? ":$z" : ''));
	}else{
		$ND::ERROR .= p b q{Couldn't parse coords};
		return $BODY;
	}

	if ($self->isMember && param('cmd') eq 'arbiter'){
		my $query = $DBH->prepare(q{SELECT count(*) AS friendlies FROM current_planet_stats WHERE x = ? AND y = ? 
			AND (planet_status IN ('Friendly','NAP') OR relationship IN ('Friendly','NAP'))});
		my ($count) = $DBH->selectrow_array($query,undef,$x,$y);
		if ($count > 0){
			$BODY->param(Arbiter => '<b>DO NOT ATTACK THIS GAL</b>');
		}else{
			$BODY->param(Arbiter => '<b>KILL THESE BASTARDS</b>');
		}
		log_message $ND::UID,"Arbiter check on $x:$y";
	}

	my $where = '';
	my $extra_columns = '';

	$where = 'AND z = ?' if defined $z;
	if ($self->isMember && $self->isOfficer){
		$extra_columns = ",planet_status,hit_us, alliance,relationship,nick";
	}elsif ($self->isMember && $self->isBC){
		$extra_columns = ", planet_status,hit_us, alliance,relationship";
	}

	my $query = $DBH->prepare(qq{Select id,coords(x,y,z), ((ruler || ' OF ') || p.planet) as planet,race, size, score, value, xp, sizerank, scorerank, valuerank, xprank, p.value - p.size*200 - coalesce(c.metal+c.crystal+c.eonium,0)/150 - coalesce(c.structures,(SELECT avg(structures) FROM covop_targets)::int)*1500 AS fleetvalue,(c.metal+c.crystal+c.eonium)/100 AS resvalue  $extra_columns from current_planet_stats p LEFT OUTER JOIN covop_targets c ON p.id = c.planet where x = ? AND y = ? $where order by x,y,z asc});

	if (defined $z){
		$query->execute($x,$y,$z);
	}else{
		$query->execute($x,$y);
		if ($self->isMember && ($self->isBC || $self->isOfficer) && !$self->isHC){
			log_message $ND::UID,"BC browsing $x:$y";
		}
	}
	my @planets;
	my $planet_id = undef;
	my $i = 0;
	while (my ($id,$coords,$planet,$race,$size,$score,$value,$xp,$sizerank,$scorerank,$valuerank,$xprank
			,$fleetvalue,$resvalue,$planet_status,$hit_us,$alliance,$relationship,$nick) = $query->fetchrow){
		$planet_id = $id;
		my %planet = (Coords => $coords, Planet => $planet, Race => $race, Size => "$size ($sizerank)"
			, Score => "$score ($scorerank)", Value => "$value ($valuerank)", XP => "$xp ($xprank)"
			, FleetValue => "$fleetvalue ($resvalue)");
		if ($self->isMember && ($self->isOfficer || $self->isBC)){
			$planet{HitUs} = $hit_us;
			$planet{Alliance} = "$alliance ($relationship)";
			$planet{Nick} = "$nick ($planet_status)";
			$planet{PlanetStatus} = $planet_status;
			$planet{Relationship} = $relationship;
			#$planet{isBC} = 1;
			if ($z && $alliance eq 'NewDawn' && not ($self->isHC || $self->isOfficer)){
				log_message $ND::UID,"BC browsing ND planet $coords tick $self->{TICK}";
			}
		}
		$i++;
		$planet{ODD} = $i % 2;
		push @planets,\%planet;
	}
	$BODY->param(Planets => \@planets);

	if ($z && $planet_id){
		$BODY->param(OnePlanet => 1);

		my $query = $DBH->prepare(q{ 
			SELECT i.mission, i.tick AS landingtick,MIN(eta) AS eta, i.amount, coords(p.x,p.y,p.z) AS target
			FROM intel i
			JOIN (planets
			NATURAL JOIN planet_stats) p ON i.target = p.id
			JOIN (planets
			NATURAL JOIN planet_stats) p2 ON i.sender = p2.id
			WHERE  p.tick = ( SELECT max(tick) FROM planet_stats) AND i.tick > tick() AND i.uid = -1 
			AND p2.tick = p.tick AND p2.id = ?
			GROUP BY p.x,p.y,p.z,p2.x,p2.y,p2.z,i.mission,i.tick,i.amount,i.ingal,i.uid
			ORDER BY p.x,p.y,p.z});
		$query->execute($planet_id);
		my @missions;
		while (my ($mission,$landingtick,$eta,$amount,$target) = $query->fetchrow){
			push @missions,{Target => $target, Mission => $mission, LandingTick => $landingtick
				, ETA => $eta, Amount => $amount};
		}
		$BODY->param(Missions => \@missions);

		my @scans;
		$query = $DBH->prepare(q{SELECT value,tick FROM planet_stats 
			WHERE id = ? AND tick > tick() - 24});
		my $scan = q{
		<p>Value the last 24 ticks</p>
		<table><tr><th>Tick</th><th>Value</th><th>Difference</th></tr>};
		my $old = 0;
		$query->execute($planet_id);
		while (my($value,$tick) = $query->fetchrow){
			my $diff = $value-$old;
			$old = $value;
			my $class = 'Defend';
			$class = 'Attack' if $diff < 0;
			$scan .= qq{<tr><td>$tick</td><td>$value</td><td class="$class">$diff</td></tr>};
		}
		$scan .= q{</table>};
		push @scans, {Scan => $scan};

		$query = $DBH->prepare(q{SELECT x,y,z,tick FROM planet_stats WHERE id = ? ORDER BY tick ASC});
		$scan = q{
		<p>Previous Coords</p>
		<table><tr><th>Tick</th><th>Value</th><th>Difference</th></tr>};
		$query->execute($planet_id);
		$x = $y = $z = 0;
		while (my($nx,$ny,$nz,$tick) = $query->fetchrow){
			if ($nx != $x || $ny != $y || $nz != $z){
				$x = $nx;
				$y = $ny;
				$z = $nz;
				$scan .= qq{<tr><td>$tick</td><td>$x:$y:$z</td></tr>};
			}
		}
		$scan .= q{</table>};
		push @scans, {Scan => $scan};

		$query = $DBH->prepare(q{SELECT DISTINCT ON (type) type,scan_id, tick, scan FROM scans WHERE planet = ?
			GROUP BY type,scan_id, tick, scan ORDER BY type,tick DESC});
		$query->execute($planet_id);
		my %scans;
		while (my($type,$scan_id,$tick,$scan) = $query->fetchrow){
			$scans{$type} = [$scan_id,$tick,$scan];
		}
		for my $type ('Planet','Jumpgate','Unit','Military','Fleet Analysis','Surface Analysis','Technology Analysis','News'){
			next unless exists $scans{$type};
			my $scan_id = $scans{$type}->[0];
			my $tick = $scans{$type}->[1];
			my $scan = $scans{$type}->[2];
			if ($self->{TICK} - $tick > 10){
				$scan =~ s{<table( cellpadding="\d+")?>}{<table$1 class="old">};
			}
			push @scans,{Scan => qq{
				<p><b><a href="http://game.planetarion.com/showscan.pl?scan_id=$scan_id">$type</a> Scan from tick $tick</b></p>
				$scan}};
		}

		$BODY->param(Scans => \@scans);
	}
	return $BODY;
}

1;
