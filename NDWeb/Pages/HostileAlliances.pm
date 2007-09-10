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
package NDWeb::Pages::HostileAlliances;
use strict;
use warnings FATAL => 'all';
use ND::Include;
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{hostileAlliances} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Hostile Alliances';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isHC;

	my $begintick = 0;
	my $endtick = $self->{TICK};
	if (param('ticks')){
		$begintick = $endtick - param('ticks');
	}elsif(defined param('begintick') && defined param('endtick')){
		$begintick = param('begintick');
		$endtick = param('endtick');

	}
	my $query = $DBH->prepare(q{
		SELECT s.alliance_id AS id,s.alliance AS name,count(*) AS hostilecount
FROM calls c 
	JOIN incomings i ON i.call = c.id
	JOIN current_planet_stats s ON i.sender = s.id
WHERE c.landing_tick - i.eta > $1 and c.landing_tick - i.eta < $2
GROUP BY s.alliance_id,s.alliance
ORDER BY hostilecount DESC
		})or $ND::ERROR .= $DBH->errstr;
	$query->execute($begintick,$endtick) or $ND::ERROR .= $DBH->errstr;
	my @alliances;
	my $i = 0;
	my $tick = $self->{TICK};
	while (my $alliance = $query->fetchrow_hashref){
		$i++;
		$alliance->{ODD} = $i % 2;
		push @alliances, $alliance;
	}
	$BODY->param(Alliances => \@alliances);
	$BODY->param(Ticks => $endtick - $begintick);
	$BODY->param(BeginTick =>$begintick);
	$BODY->param(EndTick =>$endtick);
	return $BODY;
}
1;
