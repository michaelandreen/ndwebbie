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
		my $update = $DBH->prepare(q{INSERT INTO covop_attacks (uid,id,tick) VALUES(?,?,tick())});
		$update->execute($ND::UID,$1) or warn $DBH->errstr;
	}

	my $list = '';
	my $where = '';
	if (defined param('list') && param('list') eq 'distwhores'){
		$list = 'list=distwhores';
		$where = qq{AND distorters > 0 $show
		ORDER BY distorters DESC,COALESCE(seccents::float/structures*100,0)ASC}
	}else{
		$where = qq{AND MaxResHack > 130000
		$show
		ORDER BY minalert ASC,MaxResHack DESC};
	}
	$BODY->param(List => $list);

	my $query = $DBH->prepare(qq{SELECT id, coords, metal, crystal, eonium
		, covop_alert(seccents,structures,gov,0) AS minalert 
		, covop_alert(seccents,structures,gov,50) AS maxalert 
		, distorters,gov
		, MaxResHack,co.tick AS lastcovop
		FROM (SELECT p.id,coords(x,y,z), metal,crystal,eonium,
			seccents,NULLIF(ss.total::integer,0) AS structures,distorters
			,max_bank_hack(metal,crystal,eonium,p.value
				,(SELECT value FROM current_planet_stats WHERE id = ?)) AS MaxResHack
			, planet_status, relationship,gov
			FROM current_planet_stats p
				LEFT OUTER JOIN planet_scans ps ON p.id = ps.planet
				LEFT OUTER JOIN structure_scans ss ON p.id = ss.planet
			) AS foo
			LEFT OUTER JOIN (SELECT id,max(tick) AS tick FROM covop_attacks GROUP BY id) co USING (id)
		WHERE (metal IS NOT NULL OR seccents IS NOT NULL)
		$where
	}) or warn $DBH->errstr;
	$query->execute($self->{PLANET}) or warn $DBH->errstr;

	my @targets;
	while (my $target = $query->fetchrow_hashref){
		push @targets,$target;
	}
	$BODY->param(Targets => \@targets);
	return $BODY;
}

1;
