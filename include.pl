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


sub isMember {
	return exists $ND::GROUPS{Members};
}

sub isHC {
	return exists $ND::GROUPS{HC};
}

sub isDC {
	return exists $ND::GROUPS{DC};
}

sub isBC {
	return exists $ND::GROUPS{BC};
}

sub isOfficer {
	return exists $ND::GROUPS{Officers};
}

sub isScanner {
	return exists $ND::GROUPS{Scanners};
}

sub isIntel {
	return exists $ND::GROUPS{Intel};
}

sub parseMarkup {
	my ($text) = @_;

	$text =~ s{\n}{\n<br/>}g;
	$text =~ s{\[B\](.*?)\[/B\]}{<b>$1</b>};
	return $text;
}

sub min {
    my ($x,$y) = @_;
    return ($x > $y ? $y : $x);
}

sub max {
    my ($x,$y) = @_;
    return ($x < $y ? $y : $x);
}

sub listTargets {
	my $query = $ND::DBH->prepare(qq{SELECT t.id, r.id AS raid, r.tick+c.wave-1 AS landingtick, released_coords, coords(x,y,z),c.launched,c.wave
FROM raid_claims c
	JOIN raid_targets t ON c.target = t.id
	JOIN raids r ON t.raid = r.id
	JOIN current_planet_stats p ON t.planet = p.id
WHERE c.uid = ? AND r.tick+c.wave > ? AND r.open AND not r.removed
ORDER BY r.tick+c.wave,x,y,z});
	$query->execute($ND::UID,$ND::TICK);
	my @targets;
	while (my $target = $query->fetchrow_hashref){
		my $coords = "Target $target->{id}";
		$coords = $target->{coords} if $target->{released_coords};
		push @targets,{Coords => $coords, Launched => $target->{launched}, Raid => $target->{raid}
			, Target => $target->{id}, Tick => $target->{landingtick}, Wave => $target->{wave}};
	}
	my $template = HTML::Template->new(filename => "templates/targetlist.tmpl");
	$template->param(Targets => \@targets);
	return $template->output;
}

sub alliances {
	my ($alliance) = @_;
	my @alliances;
	push @alliances,{Id => -1, Name => '&nbsp;', Selected => not $alliance};
	my $query = $ND::DBH->prepare(q{SELECT id,name FROM alliances ORDER BY name});
	$query->execute;	
	while (my $ally = $query->fetchrow_hashref){
		push @alliances,{Id => $ally->{id}, Name => $ally->{name}, Selected => $alliance == $ally->{id}};
	}
	return @alliances;
}

sub intelquery {
	my ($columns,$where) = @_;
	return qq{
SELECT $columns, i.mission, i.tick AS landingtick,MIN(i.eta) AS eta, i.amount, i.ingal, u.username
FROM (intel i NATURAL JOIN users u)
	JOIN current_planet_stats t ON i.target = t.id
	JOIN current_planet_stats o ON i.sender = o.id
WHERE $where 
GROUP BY i.tick,i.mission,t.x,t.y,t.z,o.x,o.y,o.z,i.amount,i.ingal,u.username,t.alliance,o.alliance 
ORDER BY i.tick DESC, i.mission};
}

1;
