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
our $BODY;
our $DBH;
my $error;

$ND::TEMPLATE->param(TITLE => 'Alliance Resources');

die "You don't have access" unless isHC();

my $order = "respplanet DESC";
if (defined param('order') && param('order') =~ /^(size|score|resources|respplanet|nscore|nscore2|nscore3)$/){
	$order = "$1 DESC";
}


my $query = $DBH->prepare(qq{
SELECT a.id,a.name,a.relationship,s.members,s.score,s.size,r.resources,r.planets, resources/planets AS respplanet, 
	resources / 300 AS scoregain, score + (resources / 300) AS nscore, 
	(resources/planets*LEAST(members,60))/300 AS scoregain2, score + (resources/planets*LEAST(members,60))/300 AS nscore2,
	(s.size::int8*(1464-tick())*250)/100 + score + (resources/planets*LEAST(members,60))/300 AS nscore3,
	(s.size::int8*(1464-tick())*250)/100 AS scoregain3
FROM (SELECT alliance_id AS id,sum(metal+crystal+eonium) AS resources, count(*) AS planets 
		FROM planets p join covop_targets c ON p.id = c.planet GROUP by alliance_id) r 
	NATURAL JOIN alliances a 
	LEFT OUTER JOIN (SELECT * FROM alliance_stats WHERE tick = (SELECT max(tick) FROM alliance_stats)) s ON a.id = s.id
ORDER BY $order
	});
$query->execute;
my @alliances;
my $i = 0;
while (my $alliance = $query->fetchrow_hashref){
	$i++;
	$alliance->{ODD} = $i % 2;
	push @alliances,$alliance;
}
$BODY->param(Alliances => \@alliances);

$BODY->param(Error => $error);
1;
