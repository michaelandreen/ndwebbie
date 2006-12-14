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
use POSIX;
our $BODY;
our $DBH;
our $LOG;

$ND::TEMPLATE->param(TITLE => 'Defense Calls');

die "You don't have access" unless isBC();


my $call;
if (param('call') =~ /^(\d+)$/){
	my $query = $DBH->prepare(q{});
	$call = $DBH->selectrow_hashref($query,undef,$1);
}

if ($call){
}else{
	my $where = 'open AND c.landing_tick-6 > tick()';
	if (param('show') eq 'covered'){
		$where = 'covered';
	}elsif (param('show') eq 'all'){
		$where = 'true';
	}elsif (param('show') eq 'uncovered'){
		$where = 'not covered';
	}
	my $query = $DBH->prepare(qq{
SELECT c.id, coords(p.x,p.y,p.z), u.defense_points, c.landing_tick, 
	TRIM('/' FROM concat(p2.race||'/')) AS race, TRIM('/' FROM concat(i.amount||'/')) AS amount,
	TRIM('/' FROM concat(i.eta||'/')) AS eta, TRIM('/' FROM concat(i.shiptype||'/')) AS shiptype,
	TRIM('/' FROM concat(c.landing_tick - tick() ||'/')) AS curreta,
	TRIM('/' FROM concat(p2.alliance ||'/')) AS alliance,
	TRIM('/' FROM concat(coords(p2.x,p2.y,p2.z) ||'/')) AS attackers
FROM calls c 
	JOIN incomings i ON i.call = c.id
	JOIN users u ON c.member = u.uid
	JOIN current_planet_stats p ON u.planet = p.id
	JOIN current_planet_stats p2 ON i.sender = p2.id
WHERE $where
GROUP BY c.id, p.x,p.y,p.z, u.username, c.landing_tick, c.info,u.defense_points
ORDER BY c.landing_tick DESC
		})or print $DBH->errstr;
	$query->execute or print $DBH->errstr;
	my @calls;
	my $i = 0;
	while (my $call = $query->fetchrow_hashref){
		$call->{ODD} = $i % 2;
		push @calls, $call;
		$i++;
	}
	$BODY->param(Calls => \@calls);
}
1;
