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
package ND::IRC::Usermgm;
use strict;
use warnings;
use ND::DB;
use ND::IRC::Access;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/addUser whois flags flag laston addPoints chattrG setHost deactivateUser/;

sub addUser {
	my ($nick,$pnick) = @_;
	DB();
	if (hc()){
		$pnick = $nick unless $pnick;
		my $host = "$pnick.users.netgamers.org";
		my ($username,$hostname,$p_nick) = $ND::DBH->selectrow_array(q{SELECT username, hostmask,pnick
			FROM users WHERE username ILIKE ? OR hostmask ILIKE ? OR pnick ILIKE ?}
			,undef,$nick,$host,$pnick);
		if ((not defined $username) && $ND::DBH->do("INSERT INTO users (username,hostmask,pnick,password) VALUES(?,?,?,'')"
				,undef,$nick,$host,$pnick)){
			$ND::server->command("msg $ND::target Added $ND::B$nick(/$pnick)$ND::B with host: $ND::B$host$ND::B");
		}elsif(defined $username){
			$ND::server->command("msg $ND::target $ND::B$username ($p_nick)$ND::B already exists with host: $ND::B$hostname$ND::B.");

		}else{
			$ND::server->command("msg $ND::target Something went wrong when trying to add $ND::B$nick ($pnick)$ND::B with host: $ND::B$host$ND::B, ".$ND::DBH->errstr);
		}
	}else{
		$ND::server->command("msg $ND::target Only HCs are allowed to add users");
	}
}
sub whois {
	my ($nick) = @_;
	DB();
	if (officer()){
		my $f = $ND::DBH->prepare("SELECT username, hostmask, concat(flag) FROM users u LEFT OUTER JOIN (SELECT uid,flag FROM groupmembers NATURAL JOIN groups ORDER BY uid,flag ) g ON g.uid = u.uid  WHERE username ILIKE ? GROUP BY username,hostmask");
		$f->execute($nick);
		while (my @row = $f->fetchrow()){
			$ND::server->command("msg $ND::target $row[0] flags: ($row[2]) host: $row[1]");
		}
		if ($f->rows == 0){
			$ND::server->command("msg $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}
	}else{
		$ND::server->command("msg $ND::target Only officers are allowed to check that");
	}
}

sub flags {
	my ($nick) = @_;
	DB();
	unless ($1){
		my ($flags) = $ND::DBH->selectrow_array("SELECT TRIM(', ' FROM concat(flag||':'||groupname||', ')) FROM groups");
		$ND::server->command("msg $ND::target $flags");
	}elsif (hc()){
		my $f = $ND::DBH->prepare("SELECT username, concat(flag), TRIM(', ' FROM concat(groupname||', ')) FROM users u LEFT OUTER JOIN (SELECT uid,flag,groupname FROM groupmembers NATURAL JOIN groups ORDER BY uid,flag ) g ON g.uid = u.uid  WHERE username ILIKE ? GROUP BY username,hostmask");
		$f->execute($nick);
		while (my @row = $f->fetchrow()){
			$ND::server->command("msg $ND::target Flags for $row[0] on: $ND::target: $row[1]| (Global: $row[2])");
		}
		if ($f->rows == 0){
			$ND::server->command("msg $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}
	}else{
		$ND::server->command("msg $ND::target Only HCs are allowed to check that");
	}
}

sub flag {
	my ($flag) = @_;

	if (officer()|| ($ND::target eq $ND::scanchan && $flag eq 'S')){
		my $f = $ND::DBH->prepare(qq{
SELECT TRIM(', ' FROM concat(username||', ')),count(username) FROM
	(SELECT uid, username FROM users ORDER BY username) u NATURAL JOIN groupmembers gm 
	JOIN groups g ON g.gid = gm.gid
WHERE flag = ?;
			});
		if (my ($users,$count) = $ND::DBH->selectrow_array($f,undef,$flag)){
			$ND::server->command("msg $ND::target $ND::B$count$ND::B Users with flag $ND::B$flag$ND::B: $users");
		}
	}else{
		$ND::server->command("msg $ND::target Only officers are allowed to check that");
	}
}

sub laston {
	my ($flag,$min) = @_;

	if (officer()){
		my $f = $ND::DBH->prepare(qq{SELECT username,last
			FROM (SELECT uid,username, date_part('day',now() - laston)::int AS last,laston FROM users) u NATURAL JOIN groupmembers NATURAL JOIN groups WHERE flag = ? AND (last >= ? OR last IS NULL) ORDER BY laston
			});
		$min = 0 unless defined $min;
		$f->execute($flag,$min);
		my $text;
		my $i = 0;
		while (my $user = $f->fetchrow_hashref){
			$user->{last} = '?' unless defined $user->{last};
			$text .= "$user->{username}($user->{last}) ";
			$i++;
		}
		$ND::server->command("msg $ND::target $ND::B$i$ND::B Users(days) with flag $ND::B$flag$ND::B: $text");
	}else{
		$ND::server->command("msg $ND::target Only officers are allowed to check that");
	}
}

sub addPoints {
	my ($t,$nick,$p) = @_;
	DB();
	if (   ($t eq "d" && dc())
		|| ($t eq "a" && bc())
		|| ($t eq "h" && officer())
		|| ($t eq "s" && scanner())){
		my $points = 1;
		if ($p){
			$points = $p;
		}
		if ($points*$points > 400){
			$ND::server->command("msg $ND::target Values between -20 and 20 please");
			return;
		}
		my $f = $ND::DBH->prepare("SELECT uid,username FROM users WHERE username ILIKE ?");
		$f->execute($nick);
		my @row = $f->fetchrow();
		if ($f->rows == 1){
			my $type = "defense";
			$type = "attack" if $t eq "a";
			$type = "humor" if $t eq "h";
			$type = "scan" if $t eq "s";
			my ($fleets) = $ND::DBH->selectrow_array('SELECT count(*) FROM raids r JOIN raid_targets rt ON r.id = rt.raid JOIN raid_claims rc ON rt.id = rc.target WHERE not launched AND uid = ? AND tick + 24 > tick();',undef,$row[0]);
			if ($t eq 'a' && $fleets > 0 && $points > 0){
				$ND::server->command("msg $ND::target $row[1] has $fleets claimed waves the last 24 ticks that aren't marked as launched, so no points.");
				return;
			}
			$type .= "_points";
			$ND::DBH->do("UPDATE users SET $type = $type + ? WHERE uid = ?",undef,$points,$row[0]);
			$ND::server->command("msg $ND::target $row[1] has been given $points $type");
		}elsif ($f->rows == 0){
			$ND::server->command("msg $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}else{
			$ND::server->command("msg $ND::target More than 1 user matched, please refine the search");
		}
		$f->finish;

	}else{
		$ND::server->command("msg $ND::target You don't have access for that");
	}
}

sub chattrG {
	my ($nick, $flags) = @_;
	DB();
	if (hc() || ($flags =~ /^(\+|-)?x$/ && $ND::address eq 'Assassin.users.netgamers.org')){
		my $f = $ND::DBH->prepare("SELECT uid,username FROM users WHERE username ILIKE ?");
		$f->execute($nick);
		my @user = $f->fetchrow();
		if ($f->rows == 1){
			my $add = 1;
			$flags =~ /^(-)/;
			my $update;
			if ($1 eq "-"){
				$update = $ND::DBH->prepare("DELETE FROM groupmembers WHERE uid = ? AND gid = (SELECT gid FROM groups WHERE flag = ?)");
			}else{
				$update = $ND::DBH->prepare("INSERT INTO groupmembers (uid,gid) VALUES(?,(SELECT gid FROM groups WHERE flag = ?))");
			}
			while ($flags =~ m/(\w)/g){ 
				$update->execute($user[0],$1);
			}
			$update = $ND::DBH->prepare("SELECT concat(flag) FROM (SELECT uid,flag FROM groupmembers NATURAL JOIN groups ORDER BY uid,flag ) g WHERE uid = ? ");
			my @flags = $ND::DBH->selectrow_array($update,undef,$user[0]);
			$ND::server->command("msg $ND::target Global flags for $user[1] are now: $flags[0]");
		}elsif ($f->rows == 0){
			$ND::server->command("msg $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}else{
			$ND::server->command("msg $ND::target More than 1 user matched, please refine the search");
		}
		$f->finish;
	}
}

sub setHost {
	my ($nick, $host) = @_;
	DB();
	if (hc()){
		my $f = $ND::DBH->prepare("SELECT uid,username FROM users WHERE username ILIKE ?");
		$f->execute($nick);
		my ($uid,$nick) = $f->fetchrow();
		if ($f->rows == 1){
			my ($username,$hostname) = $ND::DBH->selectrow_array("SELECT username, hostmask FROM users WHERE hostmask ILIKE ? AND NOT (username ILIKE ?)",undef,$host,$nick);
			if ((not defined $username) && $ND::DBH->do("UPDATE users SET hostmask = ? WHERE uid = ?",undef,$host,$uid) > 0){
				$ND::server->command("msg $ND::target Updated $ND::B$nick${ND::B}'s host to: $ND::B$host$ND::B");
			}elsif(defined $username){
				$ND::server->command("msg $ND::target $ND::B$username$ND::B already exists with host: $ND::B$hostname$ND::B.");
			}else{
				$ND::server->command("msg $ND::target Couldn't update $ND::B$username${ND::B}'s host");
			}
		}elsif ($f->rows == 0){
			$ND::server->command("msg $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}else{
			$ND::server->command("msg $ND::target More than 1 user matched, please refine the search");
		}
		$f->finish;
	}
}

sub deactivateUser {
	my ($nick) = @_;
	DB();
	if (hc()){
		my $f = $ND::DBH->prepare("SELECT uid,username FROM users WHERE username ILIKE ?");
		$f->execute($nick);
		my ($uid,$username) = $f->fetchrow();
		if ($f->rows == 1){
			my $updated = $ND::DBH->do("UPDATE users SET hostmask = ?, password = '' WHERE uid = ?",undef,$username,$uid);
			if ($updated > 0){
				my $groups = $ND::DBH->do("DELETE FROM groupmembers WHERE uid = ?",undef,$uid);
				$ND::server->command("msg $ND::target $ND::B$username$ND::B has been deactivated.");
			}else{
				$ND::server->command("msg $ND::target Something went wrong when trying to modify $ND::B$username$ND::B");
			}
		}elsif ($f->rows == 0){
			$ND::server->command("msg $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}else{
			$ND::server->command("msg $ND::target More than 1 user matched, please refine the search");
		}
		$f->finish;
	}
}

1;
