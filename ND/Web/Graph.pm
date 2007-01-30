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

package ND::Web::Graph;
use strict;
use warnings;
use ND::Include;
use GD::Graph::lines;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/graphFromQuery/;

sub graphFromQuery {
	my ($x,$y,$settings,$query,) = @_;

	my %graph_settings = (
		line_width => 1,
		y_number_format => sub { prettyValue abs $_[0]},
		legend_placement => 'BL',
		#zero_axis => 1,
		box_axis => 0,
		boxclr => 'black',
		axislabelclr => 'black',
	);

	my $fields = $query->{NUM_OF_FIELDS};
	my @fields;
	for (my $i = 0; $i < $fields; $i++){
		push @fields,[];
	}
	while (my @result = $query->fetchrow){
		for (my $i = 0; $i < $fields; $i++){
			push @{$fields[$i]},$result[$i];
		}

	}
	$graph_settings{x_label_skip} = int(1+(scalar @{$fields[0]}) / 6);

	my $graph = GD::Graph::lines->new($x,$y);
	$graph->set_legend(@{$query->{NAME}}[1..$fields]) or die $graph->error;

	for my $key (keys %{$settings}){
		$graph_settings{$key} = $settings->{$key};
	}

	$graph->set(%graph_settings);
	my $gd = $graph->plot(\@fields) or die $graph->error;
	return $gd->png;
}

1;
