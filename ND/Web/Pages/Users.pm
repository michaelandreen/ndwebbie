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

package ND::Web::Pages::Users;
use strict;
use warnings FATAL => 'all';
use ND::Include;
use CGI qw/:standard/;
use ND::Web::Include;

our @ISA = qw/ND::Web::XMLPage/;

$ND::Web::Page::PAGES{users} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Users';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isHC;

	my $error = '';
	my $user;
	if (defined param('user') && param('user') =~ /^(\d+)$/){
		my $query = $DBH->prepare(q{
			SELECT uid,username,hostmask,coords(x,y,z) AS planet,attack_points,defense_points,scan_points,humor_points  
			FROM users u LEFT OUTER JOIN current_planet_stats p ON u.planet = p.id
			WHERE uid = ?;
			}) or $error .= "<p> Something went wrong: </p>";
		$user = $DBH->selectrow_hashref($query,undef,$1) or $error.= "<p> Something went wrong: ".$DBH->errstr."</p>";
	}


	if ($user && defined param('cmd') && param('cmd') eq 'change'){
		$DBH->begin_work;
		for my $param (param()){
			if ($param =~ /^c:(\w+)$/){
				my $column = $1;
				my $value = param($column);
				if ($column eq 'planet'){
					if ($value eq ''){
						$value = undef;
					}elsif($value =~ /^(\d+)\D+(\d+)\D+(\d+)$/){
						($value) = $DBH->selectrow_array(q{SELECT id FROM
							current_planet_stats WHERE x = ? and y = ? and z =?}
							,undef,$1,$2,$3);
					}
				}
				if ($DBH->do(qq{UPDATE users SET $column = ? WHERE uid = ? }
						,undef,$value,$user->{uid})){
					$user->{$column} = param($column);
					log_message $ND::UID,"HC set $column to $value for user: $user->{uid}";
				}else{
					$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
				}
			}
		}
		my $groups = $DBH->prepare('SELECT gid,groupname FROM groups');
		my $delgroup = $DBH->prepare(q{DELETE FROM groupmembers WHERE uid = ? AND gid = ?});
		my $addgroup = $DBH->prepare(q{INSERT INTO groupmembers (uid,gid) VALUES(?,?)});
		$groups->execute();
		while (my $group = $groups->fetchrow_hashref){
			my $query;
			next unless defined param($group->{gid});
			if (param($group->{gid}) eq 'remove'){
				$query = $delgroup;
			}elsif(param($group->{gid}) eq 'add'){
				$query = $addgroup;
			}
			if ($query){
				if ($query->execute($user->{uid},$group->{gid})){
					my ($action,$a2) = ('added','to');
					($action,$a2) = ('removed','from') if param($group->{gid}) eq 'remove';
					log_message $ND::UID,"HC $action user: $user->{uid} ($user->{username}) $a2 group: $group->{gid} ($group->{groupname})";
				}else{
					$error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
				}
			}
		}
		$DBH->commit or $error .= "<p> Something went wrong: ".$DBH->errstr."</p>";
	}

	if ($user){
		$BODY->param(User => $user->{uid});
		$BODY->param(Username => $user->{username});
		$BODY->param(Hostmask => $user->{hostmask});
		$BODY->param(Planet => $user->{planet});
		$BODY->param(Attack_points => $user->{attack_points});
		$BODY->param(Defense_points => $user->{defense_points});
		$BODY->param(Scan_points => $user->{scan_points});
		$BODY->param(humor_points => $user->{humor_points});

		my $groups = $DBH->prepare(q{SELECT g.gid,g.groupname,uid FROM groups g LEFT OUTER JOIN (SELECT gid,uid FROM groupmembers WHERE uid = ?) AS gm ON g.gid = gm.gid});
		$groups->execute($user->{uid});

		my @addgroups;
		my @remgroups;
		while (my $group = $groups->fetchrow_hashref){
			if ($group->{uid}){
				push @remgroups,{Id => $group->{gid}, Name => $group->{groupname}};
			}else{
				push @addgroups,{Id => $group->{gid}, Name => $group->{groupname}};
			}
		}
		$BODY->param(RemoveGroups => \@remgroups);
		$BODY->param(AddGroups => \@addgroups);

	}else{
		my $query = $DBH->prepare(qq{SELECT u.uid,username,TRIM(',' FROM concat(g.groupname||',')) AS groups
			FROM users u LEFT OUTER JOIN (groupmembers gm NATURAL JOIN groups g) ON gm.uid = u.uid
			WHERE u.uid > 0
			GROUP BY u.uid,username
			ORDER BY username})or $error .= $DBH->errstr;
		$query->execute or $error .= $DBH->errstr;
		my @users;
		my $i = 0;
		while (my $user = $query->fetchrow_hashref){
			$i++;
			$user->{ODD} = $i % 2;
			push @users, $user;
		}
		$BODY->param(Users => \@users);
	}
	$BODY->param(Error => $error);
	return $BODY;
}
1;
