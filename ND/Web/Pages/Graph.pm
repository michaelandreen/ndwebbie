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
use ND::Include;
use ND::Web::Graph;

use base qw/ND::Web::Image/;

$ND::Web::Page::PAGES{graph} = 'ND::Web::Pages::Graph';

sub render_body {
	my $self = shift;
	my $DBH = $self->{DBH};

	my %graph_settings = (
		y_number_format => sub { prettyValue abs $_[0]},
		y1_label => 'size',
		y2_label => 'rest',
	);
	my $img;
	if ($self->{URI} =~ m{^/\w+/(stats|ranks)/(.*)}){
		my $type = $1;
		my ($x,$y,$z);
		if ($2 =~ m{(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?$}){
			$x = $1;
			$y = $2;
			$z = $3;
		}
		my $findGraph;
		if (defined $z){
			$findGraph = $DBH->prepare(q{SELECT graph FROM planet_graphs WHERE planet = planetid($1,$2,$3,$4) AND tick = $4 AND type = $5});
			$findGraph->execute($x,$y,$z,$ND::TICK,$type) or die $DBH->errstr;
		}
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

			$graph_settings{title} = $type;
			$graph_settings{two_axes} = 1;
			$graph_settings{use_axis} = [2,1,2,2];
			$graph_settings{y_max_value} = 0 if $type eq 'ranks';
			$img = graphFromQuery 500,300,\%graph_settings,$query;
		}
	}elsif ($self->{URI} =~ m{^/\w+/alliance(avg)?/(.*)}){


		$graph_settings{title} = 'Alliance vs known members';
		$graph_settings{two_axes} = 1;
		$graph_settings{use_axis} = [1,2,1,2];
		$graph_settings{y2_label} = 'score';

		my $query;
		unless (defined $1){
			$query = $DBH->prepare(q{SELECT a.tick,a.size,a.score,memsize, memscore FROM (SELECT tick,SUM(size) AS memsize,SUM(score) AS memscore FROM planets p JOIN planet_stats ps USING (id) WHERE p.alliance_id = $1 GROUP BY tick) p JOIN alliance_stats a ON a.tick = p.tick
WHERE a.id = $1 ORDER BY tick});
		}else{
			$graph_settings{title} = 'Average alliance vs known members';
			$query = $DBH->prepare(q{SELECT a.tick,a.size/members AS size,a.score/members AS score,memsize, memscore FROM (SELECT tick,AVG(size) AS memsize,AVG(score) AS memscore FROM planets p JOIN planet_stats ps USING (id) WHERE p.alliance_id = $1 GROUP BY tick) p JOIN alliance_stats a ON a.tick = p.tick
WHERE a.id = $1 ORDER BY tick});
		}
		$query->execute($2) or die $DBH->errstr;

		$img = graphFromQuery 500,300,\%graph_settings,$query;
	}elsif ($self->{URI} =~ m{^/\w+/planetvsnd/(\d+)}){


		$graph_settings{title} = 'You vs ND AVG';
		$graph_settings{two_axes} = 1;
		$graph_settings{use_axis} = [1,2,1,2];
		$graph_settings{y2_label} = 'score';

		my $query = $DBH->prepare(q{SELECT a.tick,a.size/members as NDsize,a.score/members AS NDscore,memsize, memscore FROM (SELECT tick,size AS memsize,score AS memscore FROM planets p JOIN planet_stats ps USING (id) WHERE p.id = $1) p JOIN alliance_stats a ON a.tick = p.tick
WHERE a.id = 1 ORDER BY tick});
		$query->execute($1) or die $DBH->errstr;

		$img = graphFromQuery 500,300,\%graph_settings,$query;
	}

	die 'no image' unless defined $img;

	return $img;
};

1;
