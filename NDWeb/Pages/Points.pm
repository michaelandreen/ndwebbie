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

package NDWeb::Pages::Points;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{points} = __PACKAGE__;


sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Top Members';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isMember;

	my $type = "total";
	if (defined param('type') && param('type') =~ /^(defense|attack|total|humor|scan|rank|raid)$/){
		$type = $1;
	}
	$type .= '_points' unless ($type eq 'rank');

	my $order = 'DESC';
	$order = 'ASC' if ($type eq 'rank');

	my $limit = 'LIMIT 10';
	$limit = '' if $self->isOfficer;

	my $query = $DBH->prepare(qq{SELECT username,defense_points,attack_points,scan_points,humor_points
		,(attack_points+defense_points+scan_points/20) as total_points, rank, count(NULLIF(rc.launched,FALSE)) AS raid_points
		FROM users u LEFT OUTER JOIN raid_claims rc USING (uid)
		WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = 2)
		GROUP BY username,defense_points,attack_points,scan_points,humor_points,rank
		ORDER BY $type $order $limit});
	$query->execute;

	my @members;
	while (my ($username,$defense,$attack,$scan,$humor,$total,$rank,$raid) = $query->fetchrow){
		push @members,{Username => $username, Defense => $defense, Attack => $attack, Raid => $raid
			, Scan => $scan, Humor => $humor, Total => $total, Rank => $rank};
	}
	$BODY->param(Members => \@members);
	return $BODY;
}

1;
