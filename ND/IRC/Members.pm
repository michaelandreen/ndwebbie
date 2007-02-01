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
package ND::IRC::Members;
use strict;
use warnings;
use ND::IRC::Access;
use ND::DB;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/currentCalls showraids checkPoints findSMS/;

sub currentCalls {
	my ($verbose) = @_;
	DB();
	if (1){ #TODO: add check for member
		my $f = $ND::DBH->prepare(<<SQL
	SELECT (c.landing_tick - tick()) AS eta, concat(i.shiptype||'/') AS shiptype, dc.username,p.x
	FROM calls c 
		JOIN incomings i ON i.call = c.id
		LEFT OUTER JOIN users dc ON dc.uid = c.dc
		JOIN users u ON u.uid = c.member
		JOIN current_planet_stats p ON u.planet = p.id
	WHERE open AND (c.landing_tick - tick()) >= 7
	GROUP BY c.id,c.landing_tick,dc.username,p.x
	ORDER BY c.landing_tick;
SQL
);
		$f->execute();
		my $calls = "";
		while (my @row = $f->fetchrow()){
			chop($row[1]);
			my $dc = defined $row[2] ? $row[2] : '';
			$calls .= " (Anti $row[1] ETA: $row[0] Cluster: $row[3] DC: $dc) |"
		}
		chop($calls);
		if (defined $verbose || length $calls > 0){
			$ND::server->command("msg $ND::target Current calls: $calls");
		}
	}
}

sub showraids {
	DB();
	if (1){ #TODO: add check for member
		my $f = $ND::DBH->prepare(<<SQL
	SELECT id FROM raids 
	WHERE open AND not removed AND tick + waves - 7 > tick()
	AND id IN (SELECT raid FROM raid_access WHERE gid = 2)
SQL
);
		$f->execute();
		my $calls = "";
		while (my ($raid) = $f->fetchrow()){
			$calls .= " https://nd.ruin.nu/raids?raid=$raid |"
		}
		$calls = "No open future raids" if ($f->rows == 0);
		chop($calls);
		$ND::server->command("msg $ND::target $calls");
	}
}

sub checkPoints {
	my ($nick) = @_;
	DB();
	my $f;
	if ($nick){
		if (officer() || dc() || bc()){
			$f = $ND::DBH->prepare("SELECT username, attack_points, defense_points, scan_points, humor_points FROM users WHERE username ILIKE ?");
		}else{
			$ND::server->command("msg $ND::target Only officers are allowed to check for others");
		}
	} else{
		$f = $ND::DBH->prepare("SELECT username, attack_points, defense_points, scan_points, humor_points FROM users WHERE hostmask ILIKE ?");
		$nick = $ND::address;
	}
	if ($f){
		$f->execute($nick);
		while (my @row = $f->fetchrow()){
			$ND::server->command("msg $ND::target $row[0] has $row[1] Attack, $row[2] Defense, $row[3] Scan, $row[4] Humor points");
		}
	}
}

sub findSMS {
	my ($nick) = @_;
	DB();
	my $f;
	if (officer() || dc()){
		$f = $ND::DBH->prepare("SELECT username,COALESCE(sms,'nothing added') FROM users WHERE username ILIKE ?");
		if (my ($username,$sms) = $ND::DBH->selectrow_array($f,undef,$nick)){
			$ND::server->command("notice $ND::target $ND::B$username$ND::B has sms $ND::B$sms$ND::B");
		}else{
			$ND::server->command("notice $ND::target No hit, maybe spelling mistake, or add % as wildcard");
		}
	}else{
		$ND::server->command("notice $ND::target Only dcs and above are allowed to check for others");
	}
}

1;
