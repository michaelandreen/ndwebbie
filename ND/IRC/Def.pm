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
package ND::IRC::Def;
use strict;
use warnings;
use ND::DB;
use ND::IRC::Access;
use ND::IRC::Misc;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/showCall setType takeCall covCall ignoreCall defcall anon setDefPrio/;

sub showCall {
	my ($id) = @_;
	DB();
	if (dc()){
		my $f = $ND::DBH->prepare(<<SQL
		SELECT i.id,coords(p.x,p.y,p.z), p.planet_status,p.nick, p.alliance, p.race,i.eta,i.amount,i.fleet,i.shiptype,p.relationship,c.landing_tick - (SELECT value::integer FROM misc WHERE id = 'TICK')
		FROM incomings i
			JOIN calls c ON i.call = c.id
				JOIN current_planet_stats p ON i.sender = p.id
				WHERE i.call = ? 
				ORDER BY p.x,p.y,p.z;
SQL
);
		$f->execute($id);
		while (my @row = $f->fetchrow()){
			@row = map (valuecolor(0),@row);
			$ND::server->command("msg $ND::target (CALL $id) $row[0]: $row[1], $row[3] ($row[2]), $row[4] ($row[10]), $row[5], ETA: $row[11](/$row[6]), Amount: $row[7],  $row[8], Type: $row[9]");
		}
	}
}

sub setType {
	my ($type,$id,$x,$y,$z) = @_;
	DB();
	if (dc()){
		my $fleet;
		my $query = qq{
			SELECT i.id,call,shiptype, coords(x,y,z),c.landing_tick - tick() FROM incomings i 
				JOIN current_planet_stats p ON i.sender = p.id
				JOIN calls c ON i.call = c.id
			};
		if (defined $x && $x eq 'call'){
			$fleet = $ND::DBH->prepare(qq{
					$query
					WHERE i.call = ?
				});
			$fleet->execute($id);
		}elsif (defined $x){
			$fleet = $ND::DBH->prepare(qq{
					$query
					WHERE i.call = ? AND p.id = planetid(?,?,?,0) 
				});
			$fleet->execute($id,$x,$y,$z);
		}else{
			$fleet = $ND::DBH->prepare(qq{
					$query
					WHERE i.id = ?
				});
			$fleet->execute($id);
		}	
		while (my ($id,$call,$oldtype,$coords,$tick) = $fleet->fetchrow()){
			if($ND::DBH->do(q{UPDATE incomings SET shiptype = ? WHERE id = ?},undef,$type,$id) == 1){
				$ND::DBH->do(q{INSERT INTO log (uid,text) VALUES ((SELECT uid FROM
					users WHERE hostmask ILIKE ?),?)},undef,$ND::address,"DC set fleet: $id to: $type");
				$ND::server->command("msg $ND::target Set fleet from $coords on call $call to $type (previosly $oldtype)");
				if ($tick < 0 && not (defined $x && $x eq 'call')){
					$ND::server->command("msg $ND::target This call is old, did you use the call id, instead of inc id by accident? You can use .settypeall callid to set the type on all incs in a call.");
				}
			}
		}
	}
}
sub takeCall {
	my ($id) = @_;
	DB();
	if (dc()){
		if ($ND::DBH->do(q{UPDATE calls SET dc = (SELECT uid FROM users WHERE hostmask ILIKE ?) WHERE id = ?}
				,undef,$ND::address,$id) == 1){
			$ND::server->command("msg $ND::target Updated the DC for call $id");
		}
	}
}

sub covCall {
	my ($id) = @_;
	DB();
	if (dc()){
		if($ND::DBH->do(q{UPDATE calls SET dc = (SELECT uid FROM users WHERE hostmask ILIKE ?), covered = TRUE, open = FALSE WHERE id = ?}
				,undef,$ND::address,$id) == 1){
			$ND::server->command("msg $ND::target Marked call $id as covered");
		}
	}
}

sub ignoreCall {
	my ($id) = @_;
	DB();
	if (dc()){
		if($ND::DBH->do(q{UPDATE calls SET dc = (SELECT uid FROM users WHERE hostmask ILIKE ?), covered = FALSE, open = FALSE WHERE id = ?}
				,undef,$ND::address,$id) == 1){
			$ND::server->command("msg $ND::target Marked call $id as ignored");
		}
	}
}

sub defcall {
	my ($msg,$nick,$callnr) = @_;
	DB();
	if (dc()){
		my $call = "";
		if ($callnr){
			my $st = $ND::DBH->prepare(q{
	SELECT c.landing_tick - (SELECT value::integer FROM misc WHERE id = 'TICK'), concat(i.shiptype||'/') AS shiptype, dc.username
	FROM calls c 
		JOIN incomings i ON i.call = c.id
		LEFT OUTER JOIN users dc ON dc.uid = c.dc
	WHERE not covered AND c.id = ?
	GROUP BY c.id,c.landing_tick,dc.username
	ORDER BY c.landing_tick;
			});
			if (my @row = $ND::DBH->selectrow_array($st,undef,$callnr)){
				chop($row[1]);
				$call = "(Anti $row[1] ETA: $row[0])"
			}
		}
		$ND::server->command("notice $ND::memchan DEFENSE REQUIRED!! WAKE UP!!");
		$ND::server->command("msg $ND::memchan DEFENSE REQUIRED $msg $call MSG $nick TO RESPOND");
	}
}

sub anon {
	my ($target,$msg) = @_;
	if (dc()){
		$ND::server->command("msg $target ".chr(2).$msg);
		$ND::server->command("msg $ND::target ".chr(3)."3$1 << $2");
	}
}


sub setDefPrio {
	my ($min,$max) = @_;
	DB();
	if (hc()){
		$ND::DBH->begin_work;
		my $update = $ND::DBH->prepare('UPDATE misc SET value = ? :: int WHERE id = ?');
		$update->execute($min,'DEFMIN');
		$update->execute($max,'DEFMAX');
		if ($ND::DBH->commit){
			$ND::server->command("msg $ND::target min def prio set to $min and max set to $max");
		}else{
			$ND::server->command("msg $ND::target something went wrong");
		}
	}
}

1;
