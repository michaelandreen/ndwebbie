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

$ND::TEMPLATE->param(TITLE => 'Create/Edit Raids');

die "You don't have access" unless isBC();

my @alliances = alliances();
$BODY->param(Alliances => \@alliances);

my $raid;
if (param('raid') =~ /^(\d+)$/){
	my $query = $DBH->prepare(q{SELECT id,tick,waves,message,released_coords,open FROM raids WHERE id = ?});
	$raid = $DBH->selectrow_hashref($query,undef,$1);
}

my $groups = $DBH->prepare(q{SELECT g.gid,g.groupname,raid FROM groups g LEFT OUTER JOIN (SELECT gid,raid FROM raid_access WHERE raid = ?) AS ra ON g.gid = ra.gid WHERE g.attack});
$groups->execute($raid ? $raid->{id} : undef);

my @addgroups;
my @remgroups;
while (my $group = $groups->fetchrow_hashref){
	if ($group->{raid}){
		push @remgroups,{Id => $group->{gid}, Name => $group->{groupname}};
	}else{
		push @addgroups,{Id => $group->{gid}, Name => $group->{groupname}};
	}
}
$BODY->param(RemoveGroups => \@remgroups);
$BODY->param(AddGroups => \@addgroups);

if ($raid){
	$BODY->param(Raid => $raid->{id});
	if($raid->{open}){
		$BODY->param(Open => 'Open');
	}else{
		$BODY->param(Open => 'Close');
	}
	if($raid->{released_coords}){
		$BODY->param(ShowCoords => 'hidecoords');
		$BODY->param(ShowCoordsName => 'Hide');
	}else{
		$BODY->param(ShowCoords => 'showcoords');
		$BODY->param(ShowCoordsName => 'Show');
	}
	$BODY->param(Waves => $raid->{waves});
	$BODY->param(LandingTick => $raid->{tick});
	$BODY->param(Message => $raid->{message});
	
	my $order = "p.x,p.y,p.z";
	if (param('order') =~ /^(score|size|value|xp|race)$/){
		$order = "$1 DESC";
	}

	my $targetquery = $DBH->prepare(qq{SELECT p.id,coords(x,y,z),raid,comment,size,score,value,race,planet_status AS planetstatus,relationship,comment
		FROM current_planet_stats p JOIN raid_targets r ON p.id = r.planet 
			LEFT OUTER JOIN covop_targets c ON p.id = c.planet
		WHERE r.raid = ?
		ORDER BY $order});
	$targetquery->execute($raid->{id}) or print $DBH->errstr;
	my @targets;
	while (my $target = $targetquery->fetchrow_hashref){
		push @targets,$target;
	}
	$BODY->param(Targets => \@targets);
}else{
	$BODY->param(Waves => 3);
	$BODY->param(LandingTick => $ND::TICK+12);
}

1;
