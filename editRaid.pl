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
	my $query = $DBH->prepare(q{SELECT id,tick,waves,message,released_coords FROM raids WHERE id = ?});
	$raid = $DBH->selectrow_hashref($query,undef,$1);
}

my $groups = $DBH->prepare(q{SELECT g.gid,g.groupname,raid FROM groups g LEFT OUTER JOIN (SELECT gid,raid FROM raid_access WHERE raid = ?) AS ra ON g.gid = ra.gid WHERE g.attack});
$groups->execute($raid->{id});

my @addgroups;
my @remgroups;
while (my $group = $groups->fetchrow_hashref){
	if ($group->{raid}){
		push @remgroups,{Id => $group->{id}, Name => $group->{groupname}};
	}else{
		push @addgroups,{Id => $group->{id}, Name => $group->{groupname}};
	}
}
$BODY->param(RemoveGroups => \@remgroups);
$BODY->param(AddGroups => \@addgroups);

if ($raid){
}else{
}

1;
