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
	my $query = $DBH->prepare(q{
SELECT c.id, coords(p.x,p.y,p.z), c.landing_tick, c.info, covered, open, dc.username AS dc, u.defense_points,c.member
FROM calls c 
	JOIN users u ON c.member = u.uid
	LEFT OUTER JOIN users dc ON c.dc = dc.uid
	JOIN current_planet_stats p ON u.planet = p.id
WHERE c.id = ?});
	$call = $DBH->selectrow_hashref($query,undef,$1);
}

if ($call){
	$BODY->param(Call => $call->{id});
	$BODY->param(Coords => $call->{coords});
	$BODY->param(DefensePoints => $call->{defense_points});
	$BODY->param(LandingTick => $call->{landing_tick});
	$BODY->param(ETA => $call->{landing_tick}-$ND::TICK);
	$BODY->param(Info => $call->{info});
	if ($call->{covered}){
		$BODY->param(Cover => 'Uncover');
	}else{
		$BODY->param(Cover => 'Cover');
	}
	if ($call->{open} && !$call->{covered}){
		$BODY->param(Cover => 'Ignore');
	}else{
		$BODY->param(Cover => 'Open');
	}
	my $fleets = $DBH->prepare(q{
SELECT id,mission,landing_tick,eta, (landing_tick+eta-1) AS back FROM fleets WHERE uid = ? AND (fleet = 0 OR (landing_tick + eta > ? AND landing_tick - eta - 11 < ? ))
ORDER BY fleet ASC});
	my $ships = $DBH->prepare('SELECT ship,amount FROM fleet_ships WHERE fleet = ?');
	$fleets->execute($call->{member},$call->{landing_tick},$call->{landing_tick});
	my @fleets;
	while (my $fleet = $fleets->fetchrow_hashref){
		if ($fleet->{back} == $call->{landing_tick}){
			$fleet->{Fleetcatch} = 1;
		}
		$ships->execute($fleet->{id});
		my @ships;
		while (my $ship = $ships->fetchrow_hashref){
			push @ships,$ship;
		}
		$fleet->{Ships} = \@ships;
		push @fleets, $fleet;
	}
	$BODY->param(Fleets => \@fleets);
	
	my $attackers = $DBH->prepare(q{
SELECT coords(p.x,p.y,p.z), p.planet_status, p.race,i.eta,i.amount,i.fleet,i.shiptype,p.relationship,p.alliance,i.id
FROM incomings i
	JOIN current_planet_stats p ON i.sender = p.id
WHERE i.call = ?
ORDER BY p.x,p.y,p.z});
	$attackers->execute($call->{id});
	my @attackers;
	while(my $attacker = $attackers->fetchrow_hashref){
		push @attackers,$attacker;
	}
	$BODY->param(Attackers => \@attackers);
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
