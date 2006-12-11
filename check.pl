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

use strict;

$ND::TEMPLATE->param(TITLE => 'Check planets and galaxies');

our $BODY;
our $DBH;

$BODY->param(isBC => isMember() && (isOfficer() || isBC));


die "You don't have access" unless $ND::ATTACKER;

my ($x,$y,$z);
if (param('coords') =~ /(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?(?: |:(\d+))?/){
	$x = $1;
	$y = $2;
	$z = $3;
}else{
	die "Bad coords";
}

if (param('cmd') eq 'arbiter'){
}

my $where = '';
my $extra_columns = '';

$where = 'AND z = ?' if defined $z;
if (isMember() && isOfficer()){
	$extra_columns = ",planet_status,hit_us, alliance,relationship,nick";
}elsif (isMember() && isBC()){
	$extra_columns = ", planet_status,hit_us, alliance,relationship";
}

my $query = $DBH->prepare(qq{Select id,coords(x,y,z), ((ruler || ' OF ') || p.planet) as planet,race, size, score, value, xp, sizerank, scorerank, valuerank, xprank, p.value - p.size*200 - coalesce(c.metal+c.crystal+c.eonium,0)/150 - coalesce(c.structures,(SELECT avg(structures) FROM covop_targets)::int)*1500 AS fleetvalue,(c.metal+c.crystal+c.eonium)/100 AS resvalue  $extra_columns from current_planet_stats p LEFT OUTER JOIN covop_targets c ON p.id = c.planet where x = ? AND y = ? $where order by x,y,z asc});

if (defined $z){
	$query->execute($x,$y,$z);
}else{
	$query->execute($x,$y);
}
my @planets;
my $planet_id = undef;
while (my ($id,$coords,$planet,$race,$size,$score,$value,$xp,$sizerank,$scorerank,$valuerank,$xprank
		,$fleetvalue,$resvalue,$planet_status,$hit_us,$alliance,$relationship,$nick) = $query->fetchrow){
	$planet_id = $id;
	my %planet = (Coords => $coords, Planet => $planet, Race => $race, Size => "$size ($sizerank)"
		, Score => "$score ($scorerank)", Value => "$value ($valuerank)", XP => "$xp ($xprank)"
		, FleetValue => "$fleetvalue ($resvalue)");
	if (isMember() && (isOfficer() || isBC())){
		$planet{HitUs} = $hit_us;
		$planet{Alliance} = "$alliance ($relationship)";
		$planet{Nick} = "$nick ($planet_status)";
		$planet{PlanetStatus} = $planet_status;
		$planet{Relationship} = $relationship;
		$planet{isBC} = 1;
	}
	push @planets,\%planet;
}
$BODY->param(Planets => \@planets);

if ($planet_id){
	$BODY->param(OnePlanet => 1);

	my $query = $DBH->prepare(q{ 
SELECT i.mission, i.tick AS landingtick,MIN(eta) AS eta, i.amount, coords(p.x,p.y,p.z) AS target
FROM intel i
	JOIN (planets
		NATURAL JOIN planet_stats) p ON i.target = p.id
	JOIN (planets
		NATURAL JOIN planet_stats) p2 ON i.sender = p2.id
WHERE  p.tick = ( SELECT max(tick) FROM planet_stats) AND i.tick > $TICK AND i.uid = -1 
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
	my $query = $DBH->prepare(q{SELECT value,tick FROM planet_stats 
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

	my $query = $DBH->prepare(q{SELECT x,y,z,tick FROM planet_stats WHERE id = ?});
	my $scan = q{
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

	my $query = $DBH->prepare(q{SELECT DISTINCT ON (type) type,scan_id, tick, scan FROM scans WHERE planet = ?
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
		if ($ND::TICK - $tick > 10){
			$scan =~ s{<table( cellpadding="\d+")?>}{<table$1 class="old">};
		}
		push @scans,{Scan => qq{
<p><b><a href="http://game.planetarion.com/showscan.pl?scan_id=$scan_id">$type</a> Scan from tick $tick</b></p>
$scan}};
	}

	$BODY->param(Scans => \@scans);
}

1;
