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
while (my ($id,$coords,$planet,$race,$size,$score,$value,$xp,$sizerank,$scorerank,$valuerank,$xprank
		,$fleetvalue,$resvalue,$planet_status,$hit_us,$alliance,$relationship,$nick) = $query->fetchrow){
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

1;
