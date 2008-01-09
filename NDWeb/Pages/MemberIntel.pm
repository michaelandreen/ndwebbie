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
use warnings;
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

	my $user;
	if (defined param('uid') && param('uid') =~ /^(\d+)$/){
		my $query = $DBH->prepare(q{SELECT username,uid FROM users WHERE uid = ?
			});
		$user = $DBH->selectrow_hashref($query,undef,$1);
	}

	if ($user){
		$BODY->param(UID => $user->{uid});
		my $query = $DBH->prepare(q{
			SELECT coords(t.x,t.y,t.z), i.eta, i.tick, rt.id AS ndtarget, rc.launched, inc.landing_tick
			FROM users u
			LEFT OUTER JOIN (SELECT DISTINCT * FROM fleets WHERE amount = -1) i ON i.sender = u.planet
			LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
			LEFT OUTER JOIN (SELECT rt.id,planet,tick FROM raids r 
					JOIN raid_targets rt ON r.id = rt.raid) rt ON rt.planet = i.target 
				AND (rt.tick + 12) > i.tick AND rt.tick <= i.tick 
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target AND rc.uid = u.uid AND i.tick = rt.tick + rc.wave - 1
			LEFT OUTER JOIN (SELECT sender, eta, landing_tick FROM calls c 
						JOIN incomings i ON i.call = c.id) inc ON inc.sender = i.target 
					AND (inc.landing_tick + inc.eta) >= i.tick 
					AND (inc.landing_tick - inc.eta - 1) <= (i.tick - i.eta) 
			WHERE u.uid = $1 AND i.mission = 'Attack'
			ORDER BY (i.tick - i.eta)
			});
		$query->execute($user->{uid}) or $error .= $DBH->errstr;
		my @nd_attacks;
		my @other_attacks;
		while (my $intel = $query->fetchrow_hashref){
			my $attack = {target => $intel->{coords}, tick => $intel->{tick}};
			if ($intel->{ndtarget}){
				if (defined $intel->{launched}){
					$attack->{Other} = 'Claimed '.($intel->{launched} ? 'and confirmed' : 'but NOT confirmed');
				}else{
					$attack->{Other} = 'Launched at a tick that was not claimed';
				}
				push @nd_attacks, $attack;
			}else{
				push @other_attacks, $attack;
			}
		}
		my @attacks;
		push @attacks, {name => 'ND Attacks', list => \@nd_attacks, class => 'AllyDef'};
		push @attacks, {name => 'Other', list => \@other_attacks, class => 'Attack'};
		$BODY->param(Attacks => \@attacks);

		$query = $DBH->prepare(q{
			SELECT coords(t.x,t.y,t.z),t.alliance_id, t.alliance, i.eta, i.tick, i.ingal
			FROM users u
			JOIN (SELECT DISTINCT * FROM fleets WHERE amount = -1) i ON i.sender = u.planet
			LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
			WHERE u.uid = $1 AND (i.mission = 'Defend' OR i.mission = 'AllyDef')
			ORDER BY (i.tick - i.eta)
			});
		$query->execute($user->{uid}) or $error .= $DBH->errstr;
		my @nd_def;
		my @ingal_def;
		my @other_def;
		while (my $intel = $query->fetchrow_hashref){
			my $def = {target => $intel->{coords}.(defined $intel->{alliance} ? " ($intel->{alliance})" : ''), tick => $intel->{tick}};
			if (defined $intel->{alliance_id} && $intel->{alliance_id} == 1){
				push @nd_def, $def;
			}elsif($intel->{ingal}){
				push @ingal_def, $def;
			}else{
				push @other_def, $def;
			}
		}
		my @defenses;
		push @defenses, {name => 'ND Def', list => \@nd_def, class => 'AllyDef'};
		push @defenses, {name => 'Ingal Def', list => \@ingal_def, class => 'Defend'};
		push @defenses, {name => 'Other', list => \@other_def, class => 'Attack'};
		$BODY->param(Defenses => \@defenses);

	}else{
		my $order = "attacks";
		if (defined param('order') && param('order') =~ /^(attacks|defenses|attack_points|defense_points|solo|bad_def)$/){
			$order = $1;
		}

		my $query = $DBH->prepare(qq{SELECT u.uid,u.username,u.attack_points, u.defense_points, n.tick
			,count(CASE WHEN i.mission = 'Attack' THEN 1 ELSE NULL END) AS attacks
			,count(CASE WHEN (i.mission = 'Defend' OR i.mission = 'AllyDef') THEN 1 ELSE NULL END) AS defenses
			,count(CASE WHEN i.mission = 'Attack' AND rt.id IS NULL THEN 1 ELSE NULL END) AS solo
			,count(CASE WHEN i.mission = 'Defend' OR i.mission = 'AllyDef' THEN NULLIF(i.ingal OR (t.alliance_id = 1),TRUE) ELSE NULL END) AS bad_def
			FROM users u
			JOIN groupmembers gm USING (uid)
			LEFT OUTER JOIN (SELECT DISTINCT ON (planet) planet,tick from scans where type = 'News' ORDER BY planet,tick DESC) n USING (planet)
			LEFT OUTER JOIN (SELECT DISTINCT * FROM fleets WHERE amount = -1) i ON i.sender = u.planet
			LEFT OUTER JOIN current_planet_stats t ON i.target = t.id
			LEFT OUTER JOIN (SELECT rt.id,planet,tick FROM raids r 
					JOIN raid_targets rt ON r.id = rt.raid) rt ON rt.planet = i.target 
				AND (rt.tick + 12) > i.tick AND rt.tick <= i.tick 
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target AND rc.uid = u.uid AND i.tick = rt.tick + rc.wave - 1
			WHERE gm.gid = 2
			GROUP BY u.uid,u.username,u.attack_points, u.defense_points,n.tick
			ORDER BY $order DESC});
		$query->execute() or $error .= $DBH->errstr;
		my @members;
		while (my $intel = $query->fetchrow_hashref){
			$intel->{OLD} = 'OLD' if (!defined $intel->{tick} || $self->{TICK} > $intel->{tick} + 60);
			delete $intel->{tick};
			push @members,$intel;
		}
		$BODY->param(Members => \@members);
	}
	$BODY->param(Error => $error);
	return $BODY;
}
1;
