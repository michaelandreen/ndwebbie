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
package ND::IRC::Scans;
use strict;
use warnings;
use ND::DB;
use ND::IRC::Access;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/addScan sendScan/;

sub addScan {
	my ($id,$verbose) = @_;
	DB();
	if (1){
		unless ($ND::DBH->selectrow_array("SELECT scan_id FROM scans WHERE scan_id = ? AND tick >= tick() - 48",undef,$id)){
			my @user = $ND::DBH->selectrow_array(q{SELECT uid,username, scan_points, tick() 
				FROM users WHERE hostmask ILIKE ? },undef,$ND::address);
			if ($ND::DBH->do(q{INSERT INTO scans (scan_id,tick,"type") VALUES (?,tick(),COALESCE(?,'-1'))},
					undef,$id,$user[0]) == 1){
				if (@user){
					$ND::DBH->do('UPDATE users SET scan_points = scan_points + 1 WHERE uid = ? ',undef,$user[0]);
					$user[2] += 1;
					$ND::server->command("msg $ND::target Added scan, at tick $user[3]. $user[1] points now $user[2]");
				}elsif ($verbose){
					$ND::server->command("msg $ND::target Added scan, but unknown user, no points");
				}
			}
		}elsif ($verbose){
			$ND::server->command("msg $ND::target a scan with that id has already been added within the last 48 ticks");
		}
	}
}
sub sendScan {
	my ($target,$msg) = @_;
	DB();
	if (scanner()){
		$ND::server->command("msg $target ".chr(2).$msg.chr(3)."4 (reply with /msg $ND::scanchan)");
		$ND::server->command("msg $ND::target ${ND::C}3$1 << $2");
	}
}

1;
