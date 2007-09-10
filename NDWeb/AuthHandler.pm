#!/usr/bin/perl -w -T
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

package NDWeb::AuthHandler;
use strict;
use warnings FATAL => 'all';

use ND::DB;
use Apache2::Access ();

sub handler {
	my $r = shift;
	my($res, $sent_pw) = $r->get_basic_auth_pw;
	return $res if $res != Apache2::Const::OK;

	my $dbh = ND::DB::DB();
	my ($username) = $dbh->selectrow_array(q{SELECT username FROM users WHERE
		lower(username) = lower(?) AND password = MD5(?)},undef,$r->user,$sent_pw);
	$dbh->disconnect;
	if ($username){
		$r->user($username);
		return Apache2::Const::OK;
	}
	$r->note_basic_auth_failure();
	return Apache2::Const::AUTH_REQUIRED;
}

1;
