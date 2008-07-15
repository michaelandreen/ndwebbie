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

package NDWeb::Include;
use strict;
use warnings;
require Exporter;
use BBCode::Parser;
use CGI qw/:standard/;

our @ISA = qw/Exporter/;

our @EXPORT = qw/parseMarkup min max
	intelquery html_escape
	comma_value array_expand/;

sub html_escape($) {
	return CGI::escapeHTML @_;
}

sub comma_value ($) {
	my ($v) = @_;
	$v =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;
	return $v;
}

sub parseMarkup ($) {
	my ($text) = @_;

	#$text =~ s{\n}{\n<br/>}g;
	#$text =~ s{\[B\](.*?)\[/B\]}{<b>$1</b>}gi;
	#$text =~ s{\[I\](.*?)\[/I\]}{<i>$1</i>}gi;
	#$text =~ s{\[url\](.*?)\[/url\]}{<a href="$1">$1</a>}gi;
	#$text =~ s{\[PRE\](.*?)\[/PRE\]}{<pre>$1</pre>}sgi;
	#$text =~ s{\[PRE\](.*?)\[/PRE\]}{<pre>$1</pre>}sgi;
	#$1 =~ s{<br/>}{}g;

	eval{
		my $tree = BBCode::Parser->DEFAULT->parse($text);
		$text = $tree->toHTML;
	};
	$text =~ s/\x{3}\d\d?//g; #mirc color TODO: possibly match until \x{0F} and change to [color] block
	$text =~ s/[^\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//g;
	return $text;
}


sub min {
    my ($x,$y) = @_;
    return ($x > $y ? $y : $x);
}

sub max {
    my ($x,$y) = @_;
    return ($x < $y ? $y : $x);
}

sub intelquery {
	my ($columns,$where) = @_;
	return qq{
SELECT $columns, i.mission, i.tick AS landingtick,MIN(i.eta) AS eta, i.amount, i.ingal, u.username
FROM (fleets i NATURAL JOIN users u)
	JOIN current_planet_stats t ON i.target = t.id
	JOIN current_planet_stats o ON i.sender = o.id
WHERE $where 
GROUP BY i.tick,i.mission,t.x,t.y,t.z,o.x,o.y,o.z,i.amount,i.ingal,u.username,t.alliance,o.alliance,t.nick,o.nick
ORDER BY i.tick DESC, i.mission};
}

sub array_expand ($) {
	my ($array) = @_;

	my @arrays;
	for my $string (@{$array}){
		$string =~ s/^\((.*)\)$/$1/;
		$string =~ s/"//g;
		my @array = split /,/, $string;
		push @arrays,\@array;
	}
	return \@arrays;
}



1;
