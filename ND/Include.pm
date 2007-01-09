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

package ND::Include;
use strict;
use warnings;
use CGI qw{:standard};
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/min max log_message intel_log unread_query/;

sub min {
    my ($x,$y) = @_;
    return ($x > $y ? $y : $x);
}

sub max {
    my ($x,$y) = @_;
    return ($x < $y ? $y : $x);
}

sub log_message {
	my ($uid, $message) = @_;
	my $log = $ND::DBH->prepare_cached(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)});
	$log->execute($uid,$message) or $ND::ERROR .= p($ND::DBH->errstr);
}

sub intel_log {
	my ($uid,$planet, $message) = @_;
	my $log = $ND::DBH->prepare_cached(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM planets WHERE id = $3),$1,$2)});
	$log->execute($uid,$message,$planet) or $ND::ERROR .= p($ND::DBH->errstr);
}

sub unread_query {
	return $ND::DBH->prepare_cached(q{
			SELECT count(*) AS unread
FROM forum_boards fb NATURAL JOIN forum_threads ft 
	JOIN forum_posts fp USING (ftid) LEFT OUTER JOIN 
		(SELECT * FROM forum_thread_visits WHERE uid = $1) ftv ON ftv.ftid = ft.ftid
WHERE (ftv.time IS NULL OR fp.time > ftv.time) AND fbid > 0 AND
	fbid IN (SELECT fbid FROM forum_access WHERE gid IN (SELECT groups($1)))
		});
}

1;
