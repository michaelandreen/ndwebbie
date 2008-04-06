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

package NDWeb::Pages::CovOp;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{covop} = __PACKAGE__;

sub parse {
	my ($uri) = @_;
	if ($uri =~ m{^/.*/(\w+)$}){
		param('list',$1);
	}
}

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'CovOp Targets';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isMember;

	my $show = q{AND (NOT planet_status IN ('Friendly','NAP')) AND  (relationship IS NULL OR NOT relationship IN ('Friendly','NAP'))};
	$show = '' if defined param('show') && param('show') eq 'all';
	if (defined param('covop') && param('covop') =~ /^(\d+)$/){
		my $update = $DBH->prepare('UPDATE covop_targets SET covop_by = ?, last_covop = tick() WHERE planet = ? ');
		$update->execute($ND::UID,$1);
	}

	my $list = '';
	my $where = '';
	if (defined param('list') && param('list') eq 'distwhores'){
		$list = '&amp;list=distwhores';
		$where = qq{AND distorters > 0 $show
		ORDER BY distorters DESC,COALESCE(seccents::float/structures*100,0)ASC}
	}else{
		$where = qq{AND MaxResHack > 130000
		$show
		ORDER BY COALESCE(seccents::float/structures*100,0) ASC,MaxResHack DESC,metal+crystal+eonium DESC};
	}

	my $query = $DBH->prepare(qq{SELECT id, coords, metal, crystal, eonium
		, seccents::float/structures*100 AS secs, distorters
		, MaxResHack
		FROM (SELECT p.id,coords(x,y,z), metal,crystal,eonium,
			seccents,NULLIF(ss.total,0) AS structures,distorters
			,max_bank_hack(metal,crystal,eonium,p.value
				,(SELECT value FROM current_planet_stats WHERE id = ?)) AS MaxResHack
			, planet_status, relationship
			FROM current_planet_stats p
				LEFT OUTER JOIN planet_scans ps ON p.id = ps.planet
				LEFT OUTER JOIN structure_scans ss ON p.id = ss.planet
			) AS foo
		WHERE (metal IS NOT NULL OR seccents IS NOT NULL)
		$where
	});
	$query->execute($self->{PLANET});

	my @targets;
	while (my ($id,$coords,$metal,$crystal,$eonium,$seccents,$dists,$max) = $query->fetchrow){
		push @targets,{Target => $id, Coords => $coords
			, Metal => $metal, Crystal => $crystal, Eonium => $eonium, SecCents => $seccents
			, Dists => $dists, MaxResHack => $max, List => $list};
	}
	$BODY->param(Targets => \@targets);
	return $BODY;
}

1;
