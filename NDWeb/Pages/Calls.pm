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
package NDWeb::Pages::Calls;
use strict;
use warnings;
use NDWeb::Forum;
use ND::Include;
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{calls} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Defense Calls';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isDC;

	my $call;
	my $thread;
	if (defined param('call') && param('call') =~ /^(\d+)$/){
		my $query = $DBH->prepare(q{
			SELECT c.id, coords(p.x,p.y,p.z), c.landing_tick, c.info, covered, open, dc.username AS dc, u.defense_points,c.member,u.planet, u.username AS member, u.sms,c.ftid
			FROM calls c 
			JOIN users u ON c.member = u.uid
			LEFT OUTER JOIN users dc ON c.dc = dc.uid
			JOIN current_planet_stats p ON u.planet = p.id
			WHERE c.id = ?});
		$call = $DBH->selectrow_hashref($query,undef,$1);

		$thread = $DBH->selectrow_hashref(q{SELECT ftid AS id, subject FROM forum_threads
			where ftid = $1},undef,$call->{ftid}) or warn $DBH->errstr;
	}
	if ($call && defined param('cmd')){
		if (param('cmd') eq 'Submit'){
			$DBH->begin_work;
			if (param('ctick')){
				if ($DBH->do(q{UPDATE calls SET landing_tick = ? WHERE id = ?}
						,undef,param('tick'),$call->{id})){
					$call->{landing_tick} = param('tick');
					def_log $ND::UID,$call->{id},"Updated landing tick to [B] $call->{landing_tick} [/B]";
				}else{
					warn $DBH->errstr;
				}
			}
			if (param('cinfo')){
				if ($DBH->do(q{UPDATE calls SET info = ? WHERE id = ?}
						,undef,param('info'),$call->{id})){
					$call->{info} = param('info');
					def_log $ND::UID,$call->{id},"Updated info";
				}else{
					warn $DBH->errstr;
				}
			}
			$DBH->commit or warn $DBH->errstr;
		}elsif(param('cmd') =~ /^(Cover|Uncover|Ignore|Open|Take) call$/){
			my $extra_vars = '';
			if (param('cmd') eq 'Cover call'){
				$extra_vars = ", covered = TRUE, open = FALSE";
			}elsif (param('cmd') eq 'Uncover call'){
				$extra_vars = ", covered = FALSE, open = TRUE";
			}elsif (param('cmd') eq 'Ignore call'){
				$extra_vars = ", covered = FALSE, open = FALSE";
			}elsif (param('cmd') eq 'Open call'){
				$extra_vars = ", covered = FALSE, open = TRUE";
			}
			if ($DBH->do(qq{UPDATE calls SET dc = ? $extra_vars WHERE id = ?},
					,undef,$ND::UID,$call->{id})){
				$call->{covered} = (param('cmd') eq 'Cover call');
				$call->{open} = (param('cmd') =~ /^(Uncover|Open) call$/);
				$call->{DC} = $self->{USER};
				def_log $ND::UID,$call->{id},'Changed status to: [B]'.param('cmd').'[/B]';
			}else{
				warn $DBH->errstr;
			}
		}elsif(param('cmd') eq 'Remove'){
			$DBH->begin_work;
			my $query = $DBH->prepare(q{DELETE FROM incomings WHERE id = ? AND call = ?});
			for my $param (param()){
				if ($param =~ /^change:(\d+)$/){
					if($query->execute($1,$call->{id})){
						def_log $ND::UID,$call->{id},"Deleted fleet: [B] $1 [/B]";
					}else{
						warn $DBH->errstr;
					}
				}
			}
			$DBH->commit or warn $DBH->errstr;
		}elsif(param('cmd') eq 'Change'){
			$DBH->begin_work;
			my $query = $DBH->prepare(q{UPDATE incomings SET shiptype = ? WHERE id = ? AND call = ?});
			for my $param (param()){
				if ($param =~ /^change:(\d+)$/){
					my $shiptype = escapeHTML(param("shiptype:$1"));
					if($query->execute($shiptype,$1,$call->{id})){
						def_log $ND::UID,$call->{id},"set fleet: [B] $1 [/B] to: [B] $shiptype [/B]";
					}else{
						warn $DBH->errstr;
					}
				}
			}
			$DBH->commit or warn $DBH->errstr;
		}
		if (defined $thread and param('cmd') eq 'forumpost'){
			addForumPost($DBH,$thread,$ND::UID,param('message'));
		}
	}

	if ($call){
		$BODY->param(Call => $call->{id});
		$BODY->param(Coords => $call->{coords});
		$BODY->param(DefensePoints => $call->{defense_points});
		$BODY->param(LandingTick => $call->{landing_tick});
		$BODY->param(ETA => $call->{landing_tick}-$self->{TICK});
		$BODY->param(Info => $call->{info});
		$BODY->param(DC => $call->{dc});
		$BODY->param(Member => $call->{member});
		$BODY->param(SMS => $call->{sms});
		$BODY->param(Thread => viewForumThread $thread);
		if ($call->{covered}){
			$BODY->param(Cover => 'Uncover');
		}else{
			$BODY->param(Cover => 'Cover');
		}
		if ($call->{open} && !$call->{covered}){
			$BODY->param(Ignore => 'Ignore');
		}else{
			$BODY->param(Ignore => 'Open');
		}

		my $outgoings = $DBH->prepare(q{ 
			SELECT i.id,i.mission, i.name, i.tick,eta
				, i.amount, coords(x,y,z) AS target
			FROM fleets i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) t ON i.target = t.id
					AND t.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE  i.sender = $1 
				AND (i.tick > $2 - 14 OR i.mission = 'Full fleet')
			ORDER BY i.tick,x,y,z
		});
		my $ships = $DBH->prepare('SELECT ship,amount FROM fleet_ships WHERE id = ?');
		$outgoings->execute($call->{planet},$call->{landing_tick});
		my @fleets;
		while (my $fleet = $outgoings->fetchrow_hashref){
			if (defined $fleet->{back} &&
					$fleet->{back} == $call->{landing_tick}){
				$fleet->{Fleetcatch} = 1;
			}
			$ships->execute($fleet->{id});
			my @ships;
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			$fleet->{Ships} = \@ships;
			push @fleets, $fleet;
		}
		$BODY->param(Fleets => \@fleets);

		my $defenders = $DBH->prepare(q{ 
			SELECT i.id,i.mission, i.name, i.tick,eta
				, i.amount, coords(x,y,z) AS sender
			FROM fleets i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) s ON i.sender = s.id
					AND s.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE i.target = ?
				AND i.tick = ? AND i.mission = 'Defend'
			ORDER BY i.tick,x,y,z
		});

		$defenders->execute($call->{planet},$call->{landing_tick}) or warn $DBH->errstr;
		my @defenders;
		while (my $fleet = $defenders->fetchrow_hashref){
			$fleet->{CLASS} = $fleet->{mission};
			$ships->execute($fleet->{id});
			my @ships;
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			$fleet->{Ships} = \@ships;
			push @defenders, $fleet;
		}
		$BODY->param(Defenders => \@defenders);

		my $attackers = $DBH->prepare(q{
			SELECT coords(p.x,p.y,p.z), p.planet_status, p.race,i.eta,i.amount,i.fleet,i.shiptype,p.relationship,p.alliance,i.id,p.id AS planet
			FROM incomings i
			JOIN current_planet_stats p ON i.sender = p.id
			WHERE i.call = ?
			ORDER BY p.x,p.y,p.z
		});
		$attackers->execute($call->{id});
		my @attackers;
		while(my $attacker = $attackers->fetchrow_hashref){
			$outgoings->execute($attacker->{planet},$call->{landing_tick});
			my @missions;
			while (my $mission = $outgoings->fetchrow_hashref){
				$mission->{eta} = '?' if not defined $mission->{eta};
				$mission->{amount} = '?' if not defined $mission->{amount};
				$mission->{CLASS} = $mission->{mission};
				my @ships;
				$ships->execute($mission->{id});
				while (my $ship = $ships->fetchrow_hashref){
					push @ships,$ship;
				}
				push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
				$mission->{ships} = \@ships;
				push @missions,$mission;
			}
			delete $attacker->{planet};
			$attacker->{missions} = \@missions;
			push @attackers,$attacker;
		}
		$BODY->param(Attackers => \@attackers);
	}else{
		my $where = 'open AND c.landing_tick-6 > tick()';
		if (defined param('show')){
			if (param('show') eq 'covered'){
				$where = 'covered';
			}elsif (param('show') eq 'all'){
				$where = 'true';
			}elsif (param('show') eq 'uncovered'){
				$where = 'not covered';
			}
		}
		my $pointlimits = $DBH->prepare(q{SELECT value :: int FROM misc WHERE id = ?});
		my ($minpoints) = $DBH->selectrow_array($pointlimits,undef,'DEFMIN');
		my ($maxpoints) = $DBH->selectrow_array($pointlimits,undef,'DEFMAX');

		my $query = $DBH->prepare(qq{
			SELECT id,coords(x,y,z),defense_points,landing_tick,dc,curreta,fleets,
				TRIM('/' FROM concat(DISTINCT race||' /')) AS race, TRIM('/' FROM concat(amount||' /')) AS amount,
				TRIM('/' FROM concat(DISTINCT eta||' /')) AS eta, TRIM('/' FROM concat(DISTINCT shiptype||' /')) AS shiptype,
				TRIM('/' FROM concat(DISTINCT alliance ||' /')) AS alliance,
				TRIM('/' FROM concat(coords||' /')) AS attackers 
			FROM (SELECT c.id, p.x,p.y,p.z, u.defense_points, c.landing_tick, dc.username AS dc,
				(c.landing_tick - tick()) AS curreta,p2.race, i.amount, i.eta, i.shiptype, p2.alliance,
				coords(p2.x,p2.y,p2.z),	COUNT(DISTINCT f.id) AS fleets
			FROM calls c 
			JOIN incomings i ON i.call = c.id
			JOIN users u ON c.member = u.uid
			JOIN current_planet_stats p ON u.planet = p.id
			JOIN current_planet_stats p2 ON i.sender = p2.id
			LEFT OUTER JOIN users dc ON c.dc = dc.uid
			LEFT OUTER JOIN fleets f ON f.target = u.planet AND f.tick = c.landing_tick AND f.back = f.tick + f.eta - 1
			WHERE $where
			GROUP BY c.id, p.x,p.y,p.z, c.landing_tick, u.defense_points,dc.username,p2.race,i.amount,i.eta,i.shiptype,p2.alliance,p2.x,p2.y,p2.z) a
			GROUP BY id, x,y,z,landing_tick, defense_points,dc,curreta,fleets
			ORDER BY landing_tick DESC
			})or warn $DBH->errstr;
		$query->execute or warn $DBH->errstr;
		my @calls;
		my $tick = $self->{TICK};
		while (my $call = $query->fetchrow_hashref){
			if ($call->{defense_points} < $minpoints){
				$call->{DefPrio} = 'LowestPrio';
			}elsif ($call->{defense_points} < $maxpoints){
				$call->{DefPrio} = 'MediumPrio';
			}else{
				$call->{DefPrio} = 'HighestPrio';
			}
			while ($tick - 24 > $call->{landing_tick}){
				$tick -= 24;
				push @calls,{};
			}
			$call->{attackers} =~ s{(\d+:\d+:\d+)}{<a href="/check?coords=$1">$1</a>}g;
			$call->{dcstyle} = 'Hostile' unless defined $call->{dc};
			$call->{shiptype} = $call->{shiptype};
			push @calls, $call;
		}
		$BODY->param(Calls => \@calls);
	}
	return $BODY;
}
1;
