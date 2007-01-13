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

package ND::Web::Pages::Graph;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use ND::Include;
use GD::Graph::lines;

$ND::PAGES{graph} = {parse => \&parse, process => \&process, render=> \&render};

sub parse {
	my ($uri) = @_;
	$ND::USETEMPLATE = 0;
}

sub process {

}

sub render {
	my ($DBH,$uri) = @_;

	my $type;
	my ($x,$y,$z);
	if ($uri =~ m{^/\w+/(stats|ranks)/(.*)}){
		$type = $1;
		if ($2 =~ m{(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))(?: |:(\d+))?$}){
			$x = $1;
			$y = $2;
			$z = $3;
		}
	}

	die "Not a proper type" unless defined $type;

	my %graph_settings = (
		line_width => 2,
		y_number_format => sub { prettyValue abs $_[0]},
		legend_placement => 'BL',
		#x_label => 'tick',
		y_label => '',
		x_label_skip => 50,
		x_tick_offset => 13,
		zero_axis => 1,
		box_axis => 0,
		boxclr => 'black',
		axislabelclr => 'black',
		title => $type,
		y1_label => 'size',
		y2_label => 'rest',


	);

	my $findGraph;
	if (defined $z){
		$findGraph = $DBH->prepare(q{SELECT graph FROM planet_graphs WHERE planet = planetid($1,$2,$3,$4) AND tick = $4 AND type = $5});
		$findGraph->execute($x,$y,$z,$ND::TICK,$type) or die $DBH->errstr;
	}

	my $img;
	if (defined $findGraph and my $graph = $findGraph->fetchrow_hashref){
		$img = $graph->{graph};
	}elsif(defined $z){
		my $planets = $DBH->prepare(q{SELECT id, tick,size,coords(x,y,z),score,size,value,xp,scorerank,sizerank,valuerank,xprank from planets natural join planet_stats where id = planetid($1,$2,$3,$4) ORDER BY tick ASC});
		$planets->execute($x,$y,$z,$ND::TICK) or die $DBH->errstr;

		my @score;
		my @size;
		my @value;
		my @xp;
		my @ticks;
		
		while (my $tick = $planets->fetchrow_hashref){
			push @ticks,$tick->{tick};
			if ($type eq 'stats'){
				push @score,$tick->{score};
				push @size,$tick->{size};
				push @value,$tick->{value};
				push @xp,$tick->{xp}*60;
			}elsif($type eq 'ranks'){
				push @score,-$tick->{scorerank};
				push @size,-$tick->{sizerank};
				push @value,-$tick->{valuerank};
				push @xp,-$tick->{xprank};
			}

		}
		my $graph = GD::Graph::lines->new(500,300);
		if ($type eq 'stats'){
			$graph->set_legend(qw{score size value xp*60}) or die $graph->error;
			$graph_settings{two_axes} = 1;
			$graph_settings{use_axis} = [2,1,2,2];
		}elsif($type eq 'ranks'){
			$graph->set_legend(qw{score size value xp}) or die $graph->error;
			$graph_settings{y_max_value} = 0;
			$graph_settings{two_axes} = 1;
			$graph_settings{use_axis} = [2,1,2,2];
		}
		$graph->set(%graph_settings);
		my $gd = $graph->plot([\@ticks,\@score,\@size,\@value,\@xp]) or die $graph->error;
		$img = $gd->png;
	}

	die 'no image' unless defined $img;

	print header(-type=> 'image/png', -Content_Length => length $img);
	binmode STDOUT;
	print $img;
}

1;
