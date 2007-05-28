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
package ND::IRC::Access;
use strict;
use warnings;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/member officer dc bc hc scanner intel masterop masterinvite/;

sub member {
	return groupmember("HM");
};
sub officer {
	return groupmember("HO");
};
sub dc {
	return groupmember("HD");
};
sub bc {
	return groupmember("HB");
};
sub hc {
	return groupmember("H");
};
sub scanner {
	return groupmember("HS");
};
sub intel {
	return groupmember("HI");
};

sub masterop {
	return groupmember("HO");
};
sub masterinvite {
	return groupmember("H");
};

sub groupmember {
	my ($groups) = @_;
	$groups = join ",", map {"'$_'"} split //, $groups;
	my $f = $ND::DBH->prepare("SELECT uid,username FROM users NATURAL JOIN groupmembers NATURAL JOIN groups WHERE flag IN ('T',$groups) AND lower(hostmask) = ?") or print $ND::DBH->errstr;
	$f->execute(lc($ND::address));
	my $user = $f->fetchrow_hashref;
	return $user;
};

1;
