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

package NDWeb::Pages::Alliances;
use strict;
use warnings FATAL => 'all';
use ND::Include;
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{alliances} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Alliances';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isHC;

	my $alliance;
	if (defined param('alliance') && param('alliance') =~ /^(\d+)$/){
		my $query = $DBH->prepare(q{SELECT id,name, relationship FROM alliances WHERE id = ?});
		$alliance = $DBH->selectrow_hashref($query,undef,$1);
	}
	if ($alliance && defined param('cmd') && param ('cmd') eq 'change'){
		$DBH->begin_work;
		if (param('crelationship')){
			my $value = escapeHTML(param('relationship'));
			if ($DBH->do(q{UPDATE alliances SET relationship = ? WHERE id =?}
					,undef,$value,$alliance->{id})){
				$alliance->{relationship} = $value;
				log_message $ND::UID,"HC set alliance: $alliance->{id} ($alliance->{name}) relationship: $value";
			}else{
				warn $DBH->errstr;
			}
		}
		my $coords = param('coords');
		my $findplanet = $DBH->prepare(q{SELECT id FROM current_planet_stats WHERE x = ? AND y = ? AND z = ?});
		my $addplanet = $DBH->prepare(q{
			UPDATE planets SET alliance_id = $2, nick = coalesce($3,nick)
			WHERE id = $1;
			});
		while ($coords =~ m/(\d+):(\d+):(\d+)(?:\s+nick=(\S+))?/g){
			my ($id) = $DBH->selectrow_array($findplanet,undef,$1,$2,$3) or $ND::ERROR .= p $DBH->errstr;
			if ($addplanet->execute($id,$alliance->{id},$4)){
				my $nick = '';
				$nick = "(nick $4)" if defined $4;
				warn "Added planet $1:$2:$3 $nick to this alliance\n";
				intel_log $ND::UID,$id,"HC Added planet $1:$2:$3 $nick to alliance: $alliance->{id} ($alliance->{name})";
			}else{
				warn $DBH->errstr;
			}
		}
		$DBH->commit or warn $DBH->errstr;
	}elsif ($alliance && defined param('cmd') && param ('cmd') eq 'remove_all'){
		$DBH->begin_work;
		my ($coords) = $DBH->selectrow_array(q{SELECT CONCAT(coords(x,y,z) || ' ') 
				FROM current_planet_stats where alliance_id = $1
			},undef,$alliance->{id});
		my $removeplanets = $DBH->prepare(q{
			UPDATE planets SET alliance_id = NULL
			WHERE alliance_id = $1;
		}) or warn $DBH->errstr;
		if ($removeplanets->execute($alliance->{id})){
			log_message $ND::UID, "HC cleaned alliance: $alliance->{id} ($alliance->{name})\n\n$coords";
			$DBH->commit or warn $DBH->errstr;
		}else{
			warn $DBH->errstr;
			$DBH->rollback;
		}
	}

	if ($alliance){
		$BODY->param(Alliance => $alliance->{name});
		$BODY->param(Id => $alliance->{id});
		my @relationships;
		for my $relationship ("","Friendly", "NAP", "Hostile"){
			push @relationships,{Rel => $relationship, Selected => defined $alliance->{relationship} && $relationship eq $alliance->{relationship}}
		}
		$BODY->param(Relationships => \@relationships);

		my $order = "p.x,p.y,p.z";
		if (defined param('order') && param('order') =~ /^(score|size|value|xp|hit_us|race)$/){
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
		while (my $member = $members->fetchrow_hashref){
			push @members,$member;
		}
		$BODY->param(Members => \@members);

		my $query = $DBH->prepare(intelquery('o.alliance AS oalliance,coords(o.x,o.y,o.z) AS origin, t.alliance AS talliance,coords(t.x,t.y,t.z) AS target',q{not ingal AND (o.alliance_id = $1 OR t.alliance_id = $1)
				AND (i.mission = 'Defend' OR i.mission = 'AllyDef')
				AND ((( t.alliance_id != o.alliance_id OR t.alliance_id IS NULL OR o.alliance_id IS NULL)))
				AND i.sender NOT IN (SELECT planet FROM users u NATURAL JOIN groupmembers gm WHERE gid = 8 AND planet IS NOT NULL)
				AND NOT (i.back IS NOT NULL AND i.back = i.tick + 4)
				}));
		$query->execute($alliance->{id}) or warn $DBH->errstr;

		my @intel;
		while (my $intel = $query->fetchrow_hashref){
			if ($intel->{ingal}){
				$intel->{missionclass} = 'ingal';
			}else{
				$intel->{missionclass} = $intel->{mission};
			}
			push @intel,$intel;
		}
		$BODY->param(Intel => \@intel);
	}else{

		my $order = "score DESC";
		if (defined param('order') && param('order') =~ /^(score|kscore|size|ksize|members|kmem|kxp|kxp|scavg|kscavg|siavg|ksiavg|kxpavg|kvalue|kvalavg)$/){
			$order = "$1 DESC";
		}
		my $query = $DBH->prepare(qq{
			SELECT DISTINCT a.id,name,COALESCE(s.score,SUM(p.score)) AS score,COALESCE(s.size,SUM(p.size)) AS size,s.members,count(p.score) AS kmem,
			COALESCE(SUM(p.score),-1) AS kscore, COALESCE(SUM(p.size),-1) AS ksize, COALESCE(SUM(p.xp),-1) AS kxp,COALESCE(SUM(p.value),-1) AS kvalue,
			COALESCE(s.score/s.members,-1) AS scavg, COALESCE(AVG(p.score)::int,-1) AS kscavg, COALESCE(s.size/s.members,-1) AS siavg,
			COALESCE(AVG(p.size)::int,-1) AS ksiavg, COALESCE(AVG(p.xp)::int,-1) AS kxpavg, COALESCE(AVG(p.value)::int,-1) AS kvalavg
			FROM alliances a 
			LEFT OUTER JOIN (SELECT * FROM alliance_stats WHERE tick = (SELECT max(tick) FROM alliance_stats)) s ON s.id = a.id
			LEFT OUTER JOIN current_planet_stats p ON p.alliance_id = a.id
			GROUP BY a.id,a.name,s.score,s.size,s.members
			ORDER BY $order
			})or warn $DBH->errstr;
		$query->execute or warn $DBH->errstr;
		my @alliances;
		while (my $alliance = $query->fetchrow_hashref){
			next unless (defined $alliance->{score} || $alliance->{kscore} > 0);
			push @alliances, $alliance;
		}
		$BODY->param(Alliances => \@alliances);
	}
	return $BODY;
}
1;
