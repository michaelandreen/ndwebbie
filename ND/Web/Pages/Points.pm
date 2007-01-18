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

package ND::Web::Pages::Points;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use ND::Web::Include;

our @ISA = qw/ND::Web::XMLPage/;

$ND::Web::Page::PAGES{points} = 'ND::Web::Pages::Points';


sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Top Members';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isMember;

	my $type = "total";
	if (defined param('type') && param('type') =~ /^(defense|attack|total|humor|scan|rank)$/){
		$type = $1;
	}
	$type .= '_points' unless ($type eq 'rank');

	my $order = 'DESC';
	$order = 'ASC' if ($type eq 'rank');

	my $limit = 'LIMIT 10';
	$limit = '' if $self->isHC;

	my $query = $DBH->prepare("SELECT username,defense_points,attack_points,scan_points,humor_points, (attack_points+defense_points+scan_points/20) as total_points, rank FROM users WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = 2) ORDER BY $type $order $limit");
	$query->execute;

	my @members;
	my $i = 0;
	while (my ($username,$defense,$attack,$scan,$humor,$total,$rank) = $query->fetchrow){
		$i++;
		push @members,{Username => $username, Defense => $defense, Attack => $attack
			, Scan => $scan, Humor => $humor, Total => $total, Rank => $rank, ODD => $i % 2};
	}
	$BODY->param(Members => \@members);
	return $BODY;
}

1;
