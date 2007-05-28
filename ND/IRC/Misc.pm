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
package ND::IRC::Misc;
use strict;
use warnings;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/valuecolor/;

$ND::defchan = "#def-ndawn";
$ND::memchan = "#nd";
$ND::scanchan = "#ndef";
$ND::bcchan = "#nd-day";
$ND::intelchan = "#ndintel";
$ND::officerchan = "#nd-officers";
$ND::communitychan = "#ndawn";
$ND::pubchan = "#newdawn";
$ND::xanchan = "#ViolatorS";

sub valuecolor {
	my $s = $_;
	$s = $_[1] if $#_ >= 1;
	$s = "" unless defined $s;
	return chr(3)."5$s".chr(15) if $s eq 'Hostile';
	return chr(3)."3$s".chr(15) if $s eq 'Friendly';
	return chr(3)."3$s".chr(15) if $s eq 'Nap' or $s eq 'NAP';
	return chr(2)."$s".chr(15) if $_[0];
	return $s;
}

1;
