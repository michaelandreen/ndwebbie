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
use warnings;
use CGI qw/:standard/;
use ND::Include;
use ND::Web::Graph;

use base qw/ND::Web::Image/;

$ND::Web::Page::PAGES{graph} = 'ND::Web::Pages::Graph';

sub render_body {
	my $self = shift;
	my $DBH = $self->{DBH};

	my $type;
	my ($x,$y,$z);
	if ($self->{URI} =~ m{^/\w+/(stats|ranks)/(.*)}){
		$type = $1;
		if ($2 =~ m{(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?$}){
			$x = $1;
			$y = $2;
			$z = $3;
		}
	}

	die "Not a proper type" unless defined $type;

	my %graph_settings = (
		y_number_format => sub { prettyValue abs $_[0]},
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
	}elsif(defined $x){
		my $query;
		if (defined $z){
			if ($type eq 'stats'){
				$query = $DBH->prepare(q{SELECT tick,score,size,value,xp*60 AS "xp*60" FROM planets natural join planet_stats WHERE id = planetid($1,$2,$3,$4) ORDER BY tick ASC});
			}elsif($type eq 'ranks'){
				$query = $DBH->prepare(q{SELECT tick,-scorerank AS score,-sizerank AS size,-valuerank AS value,-xprank AS xp FROM planets natural join planet_stats WHERE id = planetid($1,$2,$3,$4) ORDER BY tick ASC});
			}
			$query->execute($x,$y,$z,$ND::TICK) or die $DBH->errstr;
		}else{
			if ($type eq 'stats'){
				$query = $DBH->prepare(q{SELECT tick,score,size,value,xp*60 AS "xp*60" FROM galaxies WHERE x = $1 AND y = $2 ORDER BY tick ASC});
			}elsif($type eq 'ranks'){
				$query = $DBH->prepare(q{SELECT tick,-scorerank AS score,-sizerank AS size,-valuerank AS value,-xprank AS xp FROM galaxies WHERE x = $1 AND y = $2  ORDER BY tick ASC});
			}
			$query->execute($x,$y) or die $DBH->errstr;
		}
		
		$graph_settings{two_axes} = 1;
		$graph_settings{use_axis} = [2,1,2,2];
		$graph_settings{y_max_value} = 0 if $type eq 'ranks';
		$img = graphFromQuery 500,300,\%graph_settings,$query;
	}

	die 'no image' unless defined $img;

	return $img;
};

1;
