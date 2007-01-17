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

package ND::Web::Include;
use strict;
use warnings;
use CGI qw{:standard};
require Exporter;
use BBCode::Parser;

our @ISA = qw/Exporter/;

our @EXPORT = qw/isMember isHC isDC isBC isOfficer isScanner isIntel isTech parseMarkup min max listTargets
	alliances intelquery generateClaimXml/;

sub isMember {
	return exists $ND::GROUPS{Members} || isTech();
}

sub isHC {
	return exists $ND::GROUPS{HC} || isTech();
}

sub isDC {
	return exists $ND::GROUPS{DC} || isTech();
}

sub isBC {
	return exists $ND::GROUPS{BC} || isTech();
}

sub isOfficer {
	return exists $ND::GROUPS{Officers} || isTech();
}

sub isScanner {
	return exists $ND::GROUPS{Scanners} || isTech();
}

sub isIntel {
	return exists $ND::GROUPS{Intel} || isTech();
}

sub isTech {
	return exists $ND::GROUPS{Tech};
}

sub parseMarkup {
	my ($text) = @_;

	#$text =~ s{\n}{\n<br/>}g;
	#$text =~ s{\[B\](.*?)\[/B\]}{<b>$1</b>}gi;
	#$text =~ s{\[I\](.*?)\[/I\]}{<i>$1</i>}gi;
	#$text =~ s{\[url\](.*?)\[/url\]}{<a href="$1">$1</a>}gi;
	#$text =~ s{\[PRE\](.*?)\[/PRE\]}{<pre>$1</pre>}sgi;
	#$text =~ s{\[PRE\](.*?)\[/PRE\]}{<pre>$1</pre>}sgi;
	#$1 =~ s{<br/>}{}g;

	eval{
		my $tree = BBCode::Parser->DEFAULT->parse($text);
		$text = $tree->toHTML;
	};
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
	my $query = $ND::DBH->prepare(qq{SELECT t.id, r.id AS raid, r.tick+c.wave-1 AS landingtick, released_coords, coords(x,y,z),c.launched,c.wave,c.joinable
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
			, Target => $target->{id}, Tick => $target->{landingtick}, Wave => $target->{wave}
			, AJAX => $ND::AJAX, JoinName => $target->{joinable} ? 'N' : 'J'
			, Joinable => $target->{joinable} ? 'FALSE' : 'TRUE'};
	}
	my $template = HTML::Template->new(filename => "templates/targetlist.tmpl", cache => 1);
	$template->param(Targets => \@targets);
	return $template->output;
}

sub alliances {
	my ($alliance) = @_;
	my @alliances;
	$alliance = -1 unless defined $alliance;
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
GROUP BY i.tick,i.mission,t.x,t.y,t.z,o.x,o.y,o.z,i.amount,i.ingal,u.username,t.alliance,o.alliance,t.nick,o.nick
ORDER BY i.tick DESC, i.mission};
}


sub generateClaimXml {
	my ($raid, $from, $target) = @_;

	my ($timestamp) = $ND::DBH->selectrow_array("SELECT MAX(modified)::timestamp AS modified FROM raid_targets");
	$ND::BODY->param(Timestamp => $timestamp);
	if ($target){
		$target = "r.id = $target";
		$_ = listTargets();
		$ND::BODY->param(TargetList => $_);
	}else{
		$target = "r.raid = $raid->{id}";
	}

	if ($from){
		$from = "AND modified > '$from'";
	}else{
		$from = '';
	}
	my $targets = $ND::DBH->prepare(qq{SELECT r.id,r.planet FROM raid_targets r WHERE $target $from});
	$targets->execute or print p($ND::DBH->errstr);
	my $claims =  $ND::DBH->prepare(qq{ SELECT username,joinable,launched FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ?});
	my @targets;
	while (my $target = $targets->fetchrow_hashref){
		my %target;
		$target{Id} = $target->{id};
		$target{Coords} = $target->{id};
		my @waves;
		for (my $i = 1; $i <= $raid->{waves}; $i++){
			my %wave;
			$wave{Id} = $i;
			$claims->execute($target->{id},$i);
			my $joinable = 0;
			my $claimers;
			if ($claims->rows != 0){
				my $owner = 0;
				my @claimers;
				while (my $claim = $claims->fetchrow_hashref){
					$owner = 1 if ($ND::USER eq $claim->{username});
					$joinable = 1 if ($claim->{joinable});
					$claim->{username} .= '*' if ($claim->{launched});
					push @claimers,$claim->{username};
				}
				$claimers = join '/', @claimers;
				if ($owner){
					$wave{Command} = 'Unclaim';
					if ($raid->{released_coords}){
						$target{Coords} = $ND::DBH->selectrow_array('SELECT coords(x,y,z) FROM current_planet_stats WHERE id = ?',undef,$target->{planet});
					}
				}elsif ($joinable){
					$wave{Command} = 'Join';
				}else{
					$wave{Command} = 'none';
				}
			}else{
				#if (!isset($planet) || ($target->value/$planet->value > 0.4 || $target->score/$planet->score > 0.4))
				$wave{Command} = 'Claim';
			}
			$wave{Claimers} = $claimers;
			$wave{Joinable} = $joinable;
			push @waves,\%wave;
		}
		$target{Waves} = \@waves;
		push @targets,\%target;
	}
	$ND::BODY->param(Targets => \@targets);
}

1;
