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
use warnings FATAL => 'all';
use CGI qw{:standard};
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/min max log_message intel_log/;

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
		(SELECT ftid FROM forum_threads WHERE log_uid = $1),$1,$2)});
	$log->execute($uid,$message) or $ND::ERROR .= p($ND::DBH->errstr);
}

sub intel_log {
	my ($uid,$planet, $message) = @_;
	my $log = $ND::DBH->prepare_cached(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM forum_threads WHERE planet = $3),$1,$2)});
	$log->execute($uid,$message,$planet) or $ND::ERROR .= p($ND::DBH->errstr);
}

1;
