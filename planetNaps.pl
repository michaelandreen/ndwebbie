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
use warnings FATAL => 'all';

$ND::TEMPLATE->param(TITLE => 'List planet naps');

our $BODY;
our $DBH;
my $error;

die "You don't have access" unless isHC();



my $query = $DBH->prepare(qq{Select coords(x,y,z), ((ruler || ' OF ') || p.planet) as planet,race, size, score, value, xp, sizerank, scorerank, valuerank, xprank, p.value - p.size*200 - coalesce(c.metal+c.crystal+c.eonium,0)/150 - coalesce(c.structures,(SELECT avg(structures) FROM covop_targets)::int)*1500 AS fleetvalue,(c.metal+c.crystal+c.eonium)/100 AS resvalue, planet_status,hit_us, alliance,relationship,nick from current_planet_stats p LEFT OUTER JOIN covop_targets c ON p.id = c.planet WHERE planet_status IN ('Friendly','NAP') order by x,y,z asc});

$query->execute or $error .= p($DBH->errstr);
my @planets;
my $i = 0;
while (my $planet = $query->fetchrow_hashref){
	$i++;
	$planet->{ODD} = $i % 2;
	push @planets,$planet;
}
$BODY->param(Planets => \@planets);
$BODY->param(Error => $error);

1;
