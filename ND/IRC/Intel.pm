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
package ND::IRC::Intel;
use strict;
use warnings;
use ND::DB;
use ND::IRC::Access;
use ND::IRC::Misc;
use ND::Include;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/checkIntel setHostile findNick setNick setAlly setChannel/;

sub checkIntel {
	my ($x,$y,$z) = @_;
	DB();
	if (officer() || dc()){
		my $f = $ND::DBH->prepare("SELECT nick,alliance,coords(x,y,z),ruler,planet,hit_us,race,score,size,value,planet_status,relationship FROM current_planet_stats WHERE x = ? AND y = ? and z = ?");
		$f->execute($x,$y,$z);
		while (my @row = $f->fetchrow()){
			@row = map (valuecolor(1),@row);
			$ND::server->command("notice $ND::target $row[2] - $row[3] OF $row[4], Alliance=$row[1] ($row[11]), Nick=$row[0] ($row[10]), Hostile Count=$row[5], Race=$row[6], Score=$row[7], Size=$row[8], Value=$row[9] ");
		}
	}else{
		$ND::server->command("msg $ND::target Only officers are allowed to check that");
	}
}

sub setHostile {
	my ($x,$y,$z) = @_;
	DB();
	if(my $user = dc()){
		my $findid = $ND::DBH->prepare_cached(q{SELECT planetid(?,?,?,0)});
		my ($id) = $ND::DBH->selectrow_array($findid,undef,$x,$y,$z);
		my $rv = $ND::DBH->do(q{UPDATE planets SET planet_status = 'Hostile' WHERE id = $1},undef,$id);
		if ($rv == 1){
			$ND::server->command("msg $ND::target $x:$y:$z is now marked s hostile");
			intel_log $user->{uid},$id,"Set planet_status to: 'Hostile'";
		}
	}
}

sub findNick {
	my ($nick) = @_;
	DB();
	if(officer()){
		my $f = $ND::DBH->prepare("SELECT coords(x,y,z), ruler,planet,nick FROM current_planet_stats WHERE nick ILIKE ? ORDER BY x,y,z");
		$f->execute($nick);
		$ND::server->command("notice $ND::target No such nick") if $f->rows == 0;
		while (my @row = $f->fetchrow()){
			$ND::server->command("notice $ND::target $row[0] $row[1] OF $row[2] is $row[3]");
		}
	}
}
sub setNick {
	my ($x,$y,$z,$nick) = @_;
	DB();
	if (my $user = officer){
		my $findid = $ND::DBH->prepare_cached(q{SELECT planetid(?,?,?,0)});
		my ($id) = $ND::DBH->selectrow_array($findid,undef,$x,$y,$z);
		if ($ND::DBH->do('UPDATE planets SET nick = $1 WHERE id = $2'
				,undef,$nick,$id)){
			$ND::server->command("msg $ND::target $x:$y:$z has been updated");
			intel_log $user->{uid},$id,"Set nick to: $nick";
		}
	}
}

sub setAlly {
	my ($x,$y,$z,$ally) = @_;
	DB();
	if (my $user = officer){
		my $aid;
		if ($ally ne 'unknown'){
			($aid,$ally) = $ND::DBH->selectrow_array("SELECT id,name FROM alliances WHERE name ILIKE ?",undef,$ally);
		}
		if ($ally){
			my $findid = $ND::DBH->prepare_cached(q{SELECT planetid(?,?,?,0)});
			my ($id) = $ND::DBH->selectrow_array($findid,undef,$x,$y,$z);
			if($ND::DBH->do('UPDATE planets SET alliance_id = $1 WHERE id = $2'
				,undef,$aid,$id)){
				$ND::server->command("msg $ND::target Setting $x:$y:$z as $ally");
				intel_log $user->{uid},$id,"Set alliance_id to: $aid ($ally)";
			}
		}else{
			$ND::server->command("msg $ND::target Couldn't find such an alliance");
		}
	}
}

sub setChannel {
	my ($x,$y,$z,$channel) = @_;
	DB();
	if (my $user = officer()){
		my $findid = $ND::DBH->prepare_cached(q{SELECT planetid(?,?,?,0)});
		my ($id) = $ND::DBH->selectrow_array($findid,undef,$x,$y,$z);
		if ($ND::DBH->do('UPDATE planets SET channel = $1 WHERE id = $2'
				,undef,$channel,$id)){
			$ND::server->command("msg $ND::target $x:$y:$z relay channel has been set to: $channel");
			intel_log $user->{uid},$id,"Set channel to: $channel";
		}
	}
}

1;
