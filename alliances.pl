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
my $error;

$ND::TEMPLATE->param(TITLE => 'Alliances');

die "You don't have access" unless isHC();

my $alliance;
if (param('alliance') =~ /^(\d+)$/){
	my $query = $DBH->prepare(q{SELECT id,name, relationship FROM alliances WHERE id = ?});
	$alliance = $DBH->selectrow_hashref($query,undef,$1);
}
if ($alliance && param ('cmd') eq 'change'){
	$DBH->begin_work;
	if (param('crelationship')){
		my $value = escapeHTML(param('relationship'));
		if ($DBH->do(q{UPDATE alliances SET relationship = ? WHERE id =?}
				,undef,$value,$alliance->{id})){
			$alliance->{relationship} = $value;
			$LOG->execute($ND::UID,"HC set alliance: $alliance->{id} relationship: $value");
		}else{
			$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
		}
	}
	my $coords = param('coords');
	my $addplanet = $DBH->prepare(q{
UPDATE planets SET alliance_id = ?, nick = coalesce(?,nick)
WHERE id = (SELECT id FROM current_planet_stats WHERE x = ? AND y = ? AND z = ?);
		});
	while ($coords =~ m/(\d+):(\d+):(\d+)(?:\s+nick=\s*(\S+))?/g){
		if ($addplanet->execute($alliance->{id},$4,$1,$2,$3)){
			$error .= "<p> Added planet $1:$2:$3 (nick $4) to this alliance</p>";
			$LOG->execute($ND::UID,"HC Added planet $1:$2:$3 (nick $4) to alliance: $alliance->{id}");
		}else{
			$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
		}
	}
	$DBH->commit or $error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
}

if ($alliance){
	$BODY->param(Alliance => $alliance->{name});
	$BODY->param(Id => $alliance->{id});
	my @relationships;
	for my $relationship ("&nbsp;","Friendly", "NAP", "Hostile"){
		push @relationships,{Rel => $relationship, Selected => $relationship eq $alliance->{relationship}}
	}
	$BODY->param(Relationships => \@relationships);

	my $order = "p.x,p.y,p.z";
	if (param('order') =~ /^(score|size|value|xp|hit_us|race)$/){
		$order = "$1 DESC";
	}
	my $members = $DBH->prepare(qq{
SELECT coords(x,y,z), nick, ruler, planet, race, size, score, value, xp,
	planet_status,hit_us, sizerank, scorerank, valuerank, xprank
	FROM current_planet_stats p
WHERE p.alliance_id = ?
ORDER BY $order});
	my @members;
	$members->execute($alliance->{id});
	my $i = 0;
	while (my $member = $members->fetchrow_hashref){
		$i++;
		$member->{ODD} = $i % 2;
		push @members,$member;
	}
	$BODY->param(Members => \@members);

	my $query = $DBH->prepare(intelquery('o.alliance AS oalliance,coords(o.x,o.y,o.z) AS origin, t.alliance AS talliance,coords(t.x,t.y,t.z) AS target',qq{not ingal AND (t.alliance_id = ? OR t.alliance_id = ?)
	AND (i.mission = 'Defend' OR i.mission = 'AllyDef')
	AND (t.alliance_id != ? OR t.alliance_id IS NULL OR o.alliance_id != ? OR o.alliance_id IS NULL)
	AND i.sender NOT IN (SELECT planet FROM users u NATURAL JOIN groupmembers gm WHERE gid = 8 AND planet IS NOT NULL)
			}));
	$query->execute($alliance->{id},$alliance->{id},$alliance->{id},$alliance->{id}) or $error .= $DBH->errstr;

	my @intel;
	my $i = 0;
	while (my $intel = $query->fetchrow_hashref){
		if ($intel->{ingal}){
			$intel->{missionclass} = 'ingal';
		}else{
			$intel->{missionclass} = $intel->{mission};
		}
		$i++;
		$intel->{ODD} = $i % 2;
		push @intel,$intel;
	}
	$BODY->param(Intel => \@intel);
}else{

	my $order = "score DESC";
	if (param('order') =~ /^(score|kscore|size|ksize|members|kmem|kxp|kxp|scavg|kscavg|siavg|ksiavg|kxpavg|kvalue|kvalavg)$/){
		$order = "$1 DESC";
	}
	my $query = $DBH->prepare(qq{
SELECT DISTINCT a.id,name,COALESCE(s.score,SUM(p.score)) AS score,COALESCE(s.size,SUM(p.size)) AS size,s.members,count(*) AS kmem,
	COALESCE(SUM(p.score),-1) AS kscore, COALESCE(SUM(p.size),-1) AS ksize, COALESCE(SUM(p.xp),-1) AS kxp,COALESCE(SUM(p.value),-1) AS kvalue,
	COALESCE(s.score/LEAST(s.members,60),-1) AS scavg, COALESCE(AVG(p.score)::int,-1) AS kscavg, COALESCE(s.size/s.members,-1) AS siavg,
	COALESCE(AVG(p.size)::int,-1) AS ksiavg, COALESCE(AVG(p.xp)::int,-1) AS kxpavg, COALESCE(AVG(p.value)::int,-1) AS kvalavg
FROM alliances a 
	LEFT OUTER JOIN (SELECT * FROM alliance_stats WHERE tick = (SELECT max(tick) FROM alliance_stats)) s ON s.id = a.id
	LEFT OUTER JOIN current_planet_stats p ON p.alliance_id = a.id
GROUP BY a.id,a.name,s.score,s.size,s.members
ORDER BY $order
		})or $error .= $DBH->errstr;
	$query->execute or $error .= $DBH->errstr;
	my @alliances;
	my $i = 0;
	while (my $alliance = $query->fetchrow_hashref){
		$i++;
		next if ($alliance->{score} < 1 && $alliance->{kscore} < 1);
		$alliance->{ODD} = $i % 2;
		push @alliances, $alliance;
	}
	$BODY->param(Alliances => \@alliances);
}
$BODY->param(Error => $error);
1;
