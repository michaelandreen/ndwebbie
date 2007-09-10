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

package NDWeb::Pages::MemberIntel;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{memberIntel} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Member Intel';
	my $DBH = $self->{DBH};
	my $error;

	return $self->noAccess unless $self->isHC;

	my $showticks = 'AND i.tick > tick()';
	if (defined param('show')){
		if (param('show') eq 'all'){
			$showticks = '';
		}elsif (param('show') =~ /^(\d+)$/){
			$showticks = "AND (i.tick - i.eta) > (tick() - $1)";
		}
	}

	my $query = $DBH->prepare(q{SELECT u.uid,u.username,u.attack_points, u.defense_points, n.tick
		,count(CASE WHEN i.mission = 'Attack' THEN 1 ELSE NULL END) AS attacks
		,count(CASE WHEN (i.mission = 'Defend' OR i.mission = 'AllyDef') THEN 1 ELSE NULL END) AS defenses
		FROM users u
		JOIN groupmembers gm USING (uid)
		LEFT OUTER JOIN (SELECT DISTINCT ON (planet) planet,tick from scans where type = 'News' ORDER BY planet,tick DESC) n USING (planet)
		LEFT OUTER JOIN (SELECT * FROM intel WHERE amount = -1) i ON i.sender = u.planet
		LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
		WHERE gm.gid = 2
		GROUP BY u.uid,u.username,u.attack_points, u.defense_points,n.tick
		ORDER BY attacks DESC,defenses DESC});
	$query->execute() or $error .= $DBH->errstr;
	my @members;
	my $i = 0;
	while (my $intel = $query->fetchrow_hashref){
		$i++;
		$intel->{ODD} = $i % 2;
		$intel->{OLD} = 'OLD' if (!defined $intel->{tick} || $self->{TICK} > $intel->{tick} + 60);
		delete $intel->{tick};
		push @members,$intel;
	}

	$BODY->param(Members => \@members);

	$BODY->param(Error => $error);
	return $BODY;
}
1;
