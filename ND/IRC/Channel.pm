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
package ND::IRC::Channel;
use strict;
use warnings;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/op deop voice devoice/;

sub op {
	my ($nick) = @_;
	umode("op","op",$nick);
}

sub deop {
	my ($nick) = @_;
	umode("deop","op",$nick);
}

sub voice {
	my ($nick) = @_;
	umode("voice","voice",$nick);
}

sub devoice {
	my ($nick) = @_;
	umode("devoice","voice",$nick);
}

sub umode {
	my ($command,$access,$nick) = @_;
	my $where = "";
	unless (defined $nick){
		$nick = $ND::nick;
		$where = "OR f.name = 'auto_$access'";
	}

	my $mode = qq{
SELECT DISTINCT c.name FROM users u
	JOIN groupmembers g ON g.uid = u.uid
	JOIN channel_group_flags gf ON g.gid = gf.group
	JOIN channels c ON gf.channel = c.id
	JOIN channel_flags f ON f.id = gf.flag
WHERE u.hostmask ILIKE ? AND c.name = ? AND (f.name = '$access' $where);
		};
	if (masterop()){
		$mode = 1;
	}else{
		($mode) = $ND::DBH->selectrow_array($mode,undef,$ND::address,$ND::target);
	}
	if ($mode){
		$ND::server->command("$command $ND::target $nick");
	}
}

1;
