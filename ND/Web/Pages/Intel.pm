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

package ND::Web::Pages::Intel;
use strict;
use warnings FATAL => 'all';
use ND::Web::Forum;
use ND::Web::Include;
use ND::Include;
use CGI qw/:standard/;

$ND::PAGES{intel} = {parse => \&parse, process => \&process, render=> \&render};

sub parse {
	my ($uri) = @_;
	if ($uri =~ m{^/.*/(\w+)$}){
		param('list',$1);
	}
}

sub process {

}

sub render {
	my ($DBH,$BODY) = @_;

	my $error;

	$ND::TEMPLATE->param(TITLE => 'Intel');

	return $ND::NOACCESS unless isIntel() || isHC();

	my $planet;
	if (defined param('coords') && param('coords') =~ /^(\d+)(?: |:)(\d+)(?: |:)(\d+)$/){
		my $query = $DBH->prepare(q{SELECT x,y,z,coords(x,y,z),id, nick, alliance,alliance_id, planet_status,channel,ftid FROM current_planet_stats
			WHERE  x = ? AND y = ? AND z = ?});
		$planet = $DBH->selectrow_hashref($query,undef,$1,$2,$3) or $ND::ERROR .= p $DBH->errstr;
	}

	my $showticks = 'AND (i.tick - i.eta) > (tick() - 48)';
	if (defined param('show')){
		if (param('show') eq 'all'){
			$showticks = '';
		}elsif (param('show') =~ /^(\d+)$/){
			$showticks = "AND (i.tick - i.eta) > (tick() - $1)";
		}
	}

	my $thread;
	if (defined $planet){
		$thread = $DBH->selectrow_hashref(q{SELECT ftid AS id, subject FROM forum_threads
			where ftid = $1},undef,$planet->{ftid}) or $ND::ERROR .= p($DBH->errstr);
	}

	if (defined param('cmd') && param('cmd') eq 'coords'){
		my $coords = param('coords');
		$DBH->do(q{CREATE TEMPORARY TABLE coordlist (
			x integer NOT NULL,
			y integer NOT NULL,
			z integer NOT NULL,
			PRIMARY KEY (x,y,z)
			)});
		my $insert = $DBH->prepare(q{INSERT INTO coordlist (x,y,z) VALUES(?,?,?)});
		while ($coords =~ m/(\d+):(\d+):(\d+)/g){
			$insert->execute($1,$2,$3);
		}
		my $planets = $DBH->prepare(q{SELECT (((p.x || ':') || p.y) || ':') || p.z AS coords, alliance FROM current_planet_stats p
			JOIN coordlist c ON p.x = c.x AND p.y = c.y AND p.z = c.z
			ORDER BY alliance, p.x, p.y, p.z});
		$planets->execute;
		my @planets;
		while (my $planet = $planets->fetchrow_hashref){
			push @planets,$planet;
		}
		$BODY->param(CoordList => \@planets);
	}
	if (defined $thread and defined param('cmd') and param('cmd') eq 'forumpost'){
		addForumPost($DBH,$thread,$ND::UID,param('message'));
	}

	if ($planet && defined param('cmd')){
		if (param('cmd') eq 'change'){
			$DBH->begin_work;
			if (param('cnick')){
				my $value = escapeHTML(param('nick'));
				if ($DBH->do(q{UPDATE planets SET nick = ? WHERE id =?}
						,undef,$value,$planet->{id})){
					intel_log $ND::UID,$planet->{id},"Set nick to: $value";
					$planet->{nick} = $value;
				}else{
					$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
				}
			}
			if (param('cchannel')){
				my $value = escapeHTML(param('channel'));
				if ($DBH->do(q{UPDATE planets SET channel = ? WHERE id =?}
						,undef,$value,$planet->{id})){
					intel_log $ND::UID,$planet->{id},"Set channel to: $value";
					$planet->{channel} = $value;
				}else{
					$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
				}
			}
			if (param('cstatus')){
				my $value = escapeHTML(param('status'));
				if ($DBH->do(q{UPDATE planets SET planet_status = ? WHERE id =?}
						,undef,$value,$planet->{id})){
					intel_log $ND::UID,$planet->{id},"Set planet_status to: $value";
					$planet->{planet_status} = $value;
				}else{
					$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
				}
			}
			if (param('calliance')){
				if ($DBH->do(q{UPDATE planets SET alliance_id = NULLIF(?,-1) WHERE id =?}
						,undef,param('alliance'),$planet->{id})){
					intel_log $ND::UID,$planet->{id},"Set alliance_id to: ".param('alliance');
					$planet->{alliance_id} = param('alliance');
				}else{
					$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
				}
			}
			$DBH->commit or $error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
		}
	}

	if (param('coords')){
		my $channel = param('coords');
		$channel = $planet->{channel} if ($planet);
		my $findchannel = $DBH->prepare('SELECT coords(x,y,z),alliance,nick,channel FROM current_planet_stats WHERE channel ILIKE ? ');
		$findchannel->execute($channel);
		my @channelusers;
		while (my $user = $findchannel->fetchrow_hashref){
			push @channelusers,$user;
		}
		$BODY->param(ChannelUsers => \@channelusers);
	}

	if ($planet){
		$BODY->param(Coords => $planet->{coords});
		$BODY->param(Planet => $planet->{id});
		$BODY->param(Nick => $planet->{nick});
		$BODY->param(Channel => $planet->{channel});
		my @status;
		for my $status ("&nbsp;","Friendly", "NAP", "Hostile"){
			push @status,{Status => $status, Selected => defined $planet->{planet_status} && $status eq $planet->{planet_status}}
		}
		$BODY->param(PlanetStatus => \@status);
		my @alliances = alliances($planet->{alliance_id});
		$BODY->param(Alliances => \@alliances);

		$BODY->param(Thread => viewForumThread $thread);

		my $query = $DBH->prepare(intelquery('o.alliance AS oalliance,coords(o.x,o.y,o.z) AS origin',"t.id = ? $showticks"));
		$query->execute($planet->{id}) or $error .= $DBH->errstr;
		my @intellists;
		my @incomings;
		my $i = 0;
		while (my $intel = $query->fetchrow_hashref){
			if ($intel->{ingal}){
				$intel->{missionclass} = 'ingal';
			}else{
				$intel->{missionclass} = $intel->{mission};
			}
			$i++;
			$intel->{ODD} = $i % 2;
			push @incomings,$intel;
		}
		push @intellists,{Message => 'Incoming fleets', Intel => \@incomings, Origin => 1};

		$query = $DBH->prepare(intelquery('t.alliance AS talliance,coords(t.x,t.y,t.z) AS target',"o.id = ? $showticks"));
		$query->execute($planet->{id}) or $error .= $DBH->errstr;
		my @outgoings;
		$i = 0;
		while (my $intel = $query->fetchrow_hashref){
			if ($intel->{ingal}){
				$intel->{missionclass} = 'ingal';
			}else{
				$intel->{missionclass} = $intel->{mission};
			}
			$i++;
			$intel->{ODD} = $i % 2;
			push @outgoings,$intel;
		}
		push @intellists,{Message => 'Outgoing Fleets', Intel => \@outgoings, Target => 1};

		$BODY->param(IntelLIsts => \@intellists);

	}elsif(!param('coords')){
		my $query = $DBH->prepare(intelquery('o.alliance AS oalliance,coords(o.x,o.y,o.z) AS origin, t.alliance AS talliance,coords(t.x,t.y,t.z) AS target',qq{not ingal
				AND ((( t.alliance_id != o.alliance_id OR t.alliance_id IS NULL OR o.alliance_id IS NULL) AND i.mission != 'Attack')
				OR ( t.alliance_id = o.alliance_id AND i.mission = 'Attack'))
				AND i.sender NOT IN (SELECT planet FROM users u NATURAL JOIN groupmembers gm WHERE gid = 8 AND planet IS NOT NULL)
				$showticks}));
		$query->execute() or $error .= $DBH->errstr;

		my @intellists;
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
		push @intellists,{Message => q{Intel where alliances doesn't match}, Intel => \@intel, Origin => 1, Target => 1};
		$BODY->param(IntelLIsts => \@intellists);
	}
	my $query = $DBH->prepare(q{SELECT i.id, u.username, i.message, report_date FROM intel_messages i
		JOIN users u ON u.uid = i.uid
		WHERE NOT handled ORDER BY report_date});
	$query->execute;
	my @messages;
	while (my $message = $query->fetchrow_hashref){
		$message->{message} = parseMarkup($message->{message});
		push @messages,$message;
	}
	#$BODY->param(IntelMessages => \@messages);
	$BODY->param(Error => $error);
	return $BODY;
}
1;
