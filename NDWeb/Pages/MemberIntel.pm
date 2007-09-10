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


	my $query = $DBH->prepare(intelquery('o.alliance AS oalliance,coords(o.x,o.y,o.z) AS origin, coords(t.x,t.y,t.z) AS target, t.nick',"t.alliance_id = 1 $showticks"));
	$query->execute() or $error .= $DBH->errstr;
	my @intellists;
	my @incomings;
	my $i = 0;
	while (my $intel = $query->fetchrow_hashref){
		if ($intel->{ingal}){
			$intel->{missionclass} = 'ingal';
		}else{
			$intel->{missionclass} = $intel->{mission};
		}
		$intel->{oalliance} = ' ' unless $intel->{oalliance};
		$i++;
		$intel->{ODD} = $i % 2;
		push @incomings,$intel;
	}
	push @intellists,{Message => 'Incoming fleets', Intel => \@incomings, Origin => 1};

	$query = $DBH->prepare(intelquery('o.nick,coords(o.x,o.y,o.z) AS origin,t.alliance AS talliance,coords(t.x,t.y,t.z) AS target',"o.alliance_id = 1 $showticks"));
	$query->execute() or $error .= $DBH->errstr;
	my @outgoings;
	$i = 0;
	while (my $intel = $query->fetchrow_hashref){
		if ($intel->{ingal}){
			$intel->{missionclass} = 'ingal';
		}else{
			$intel->{missionclass} = $intel->{mission};
		}
		$intel->{talliance} = ' ' unless $intel->{talliance};
		$i++;
		$intel->{ODD} = $i % 2;
		push @outgoings,$intel;
	}
	push @intellists,{Message => 'Outgoing Fleets', Intel => \@outgoings, Target => 1};

	$BODY->param(IntelLIsts => \@intellists);

	$BODY->param(Error => $error);
	return $BODY;
}
1;
