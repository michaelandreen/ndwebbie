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

package NDWeb::Pages::DefLeeches;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{defLeeches} = __PACKAGE__;


sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Def Leeches';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isDC;

	my $query = $DBH->prepare(q{SELECT username,defense_points,count(id) AS calls, SUM(fleets) AS fleets, SUM(recalled) AS recalled
		FROM (SELECT username,defense_points,c.id,count(f.target) AS fleets, count(NULLIF(f.tick + f.eta -1 = f.back,TRUE)) AS recalled
			FROM users u JOIN calls c ON c.member = u.uid LEFT OUTER JOIN fleets f ON u.planet = f.target AND c.landing_tick = f.tick
			WHERE (f.mission = 'Defend' AND f.uid > 0 AND f.back IS NOT NULL AND NOT ingal)
				OR f.target IS NULL
			GROUP BY username,defense_points,c.id
			) d
		GROUP BY username,defense_points ORDER BY fleets DESC, defense_points
		});
	$query->execute;

	my @members;
	while ( my $member = $query->fetchrow_hashref){
		push @members,$member;
	}
	$BODY->param(Members => \@members);
	return $BODY;
}

1;
