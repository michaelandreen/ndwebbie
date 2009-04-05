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
use Parse::BBCode;
use CGI qw/:standard/;

our @ISA = qw/Exporter/;

our @EXPORT = qw/parseMarkup
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


my $bbc = Parse::BBCode->new({
		tags => {
			Parse::BBCode::HTML->defaults,
			'' => sub {
				my $e = ($_[2]);
				$e =~ s/\r?\n|\r/<br>\n/g;
				$e
			},
			url   => 'url:<a href="%{link}A" rel="external">%s</a>',
			quote => 'block:<div class="bbcode-quote">
<div class="bbcode-quote-head"><b>%{html}a wrote:</b></div>
<div class="bbcode-quote-body">%s</div></div>',
			code => 'block:<div class="bbcode-quote"><pre class="bbcode-code">%{html}s</pre></div>',
			img   => 'url:<a href="%{link}A" rel="external">%s</a>',
			li  => 'block:<li>%{parse}s</li>',
			size  => '<span style="font-size: %{num}a%">%s</span>',

		},
		close_open_tags   => 1,
	});

sub parseMarkup ($) {
	my ($text) = @_;

	$text = $bbc->render($text);
	if ($bbc->error){
		my $tree = $bbc->get_tree;
		$text = $tree->raw_text;
		$text = $bbc->render($text);
	}
	$text =~ s/\x{3}\d\d?//g; #mirc color TODO: possibly match until \x{0F} and change to [color] block
	$text =~ s/[^\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//g;
	return $text;
}

sub intelquery {
	my ($columns,$where) = @_;
	return qq{
SELECT $columns, i.mission, i.tick AS landingtick,MIN(i.eta) AS eta, i.amount, i.ingal, u.username
FROM (intel i NATURAL JOIN users u)
	JOIN current_planet_stats t ON i.target = t.id
	JOIN current_planet_stats o ON i.sender = o.id
WHERE $where 
GROUP BY i.tick,i.mission,t.x,t.y,t.z,o.x,o.y,o.z,i.amount,i.ingal,u.username,t.alliance,o.alliance,t.nick,o.nick,i.sender,i.target
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
