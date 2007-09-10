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

package ND::Web::Pages::TargetList;
use strict;
use warnings FATAL => 'all';
use ND::Include;
use CGI qw/:standard/;
use ND::Web::Include;

use base qw/ND::Web::XMLPage/;

$ND::Web::Page::PAGES{targetList} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'NF Value';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isHC;

	my $order = 'nfvalue';
	if (local $_ = param('order')){
		if (/^(size|value|score|xp)$/){
			$order = "$1 DESC";
		}elsif (/^(nfvalue|nfvalue2)$/){
			$order = "$1 ASC";
		}
	}

	my $alliances = '15';
	if (param('alliances') && param('alliances') =~ /^([\d,]+)$/){
		$alliances = $1;
	}
	my $query = $DBH->prepare(qq{
SELECT coords(p.x,p.y,p.z),p.alliance, p.score, p.value, p.size, p.xp,nfvalue, nfvalue - sum(pa.value) AS nfvalue2, p.race
FROM current_planet_stats p
	JOIN (SELECT g.x,g.y, sum(p.value) AS nfvalue
	FROM galaxies g join current_planet_stats p on g.x = p.x AND g.y = p.y 
	WHERE g.tick = (SELECT max(tick) from galaxies)
		AND ((planet_status IS NULL OR NOT planet_status IN ('Friendly','NAP')) AND  (relationship IS NULL OR NOT relationship IN ('Friendly','NAP'))) 
	GROUP BY g.x,g.y
	) g ON p.x = g.x AND p.y = g.y
	JOIN current_planet_stats pa ON pa.x = g.x AND pa.y = g.y
WHERE p.alliance_id IN ($alliances)
	AND pa.alliance_id IN ($alliances)
GROUP BY p.x,p.y,p.z,p.alliance, p.score, p.value, p.size, p.xp, nfvalue,p.race
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

	return $BODY;
}
1;
