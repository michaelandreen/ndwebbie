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

package NDWeb::Pages::AllianceRankings;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{alliancerankings} = __PACKAGE__;

sub parse {
	#TODO: Need to fix some links first
	#if ($uri =~ m{^/[^/]+/(\w+)}){
	#	param('order',$1);
	#}
}

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Top Alliances';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->isMember;

	my $error = '';

	$BODY->param(isHC => $self->isHC);

	my $offset = 0;
	if (defined param('offset') && param('offset') =~ /^(\d+)$/){
		$offset = $1;
	}
	$BODY->param(Offset => $offset);
	$BODY->param(PrevOffset => $offset - 100);
	$BODY->param(NextOffset => $offset + 100);

	my $order = 'scorerank';
	if (defined param('order') && param('order') =~ /^(scorerank|sizerank|members|avgsize|avgscore)$/){
		$order = $1;
	}
	$BODY->param(Order => $order);
	$order .= ' DESC' unless $order =~ /rank$/;


	#my $extra_columns = '';
	#if ($self->isHC){
	#	$extra_columns = ",alliance_status,hit_us, alliance,relationship,nick";
	#}
	my $query = $DBH->prepare(qq{SELECT a.name,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		avgsize,avgsize_gain,avgsize_gain_day,
		avgscore,avgscore_gain,avgscore_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		members,members_gain,members_gain_day
	FROM 
		( SELECT id, members,members_gain,members_gain_day, size, score, (size/members) AS avgsize, (score/members) AS avgscore, sizerank, scorerank, size_gain, score_gain, (size_gain/members) AS avgsize_gain, (score_gain/members) AS avgscore_gain, sizerank_gain, scorerank_gain, size_gain_day, score_gain_day, (size_gain_day/members) AS avgsize_gain_day, (score_gain_day/members) AS avgscore_gain_day, sizerank_gain_day, scorerank_gain_day
			FROM alliance_stats WHERE tick = (( SELECT max(tick) AS max FROM alliance_stats))) ast
		NATURAL JOIN alliances a
		ORDER BY $order LIMIT 100 OFFSET ?});
	$query->execute($offset) or $error .= p($DBH->errstr);
	my @alliances;
	my $i = 0;
	while (my $alliance = $query->fetchrow_hashref){
		for my $type (qw/members size score avgsize avgscore/){
			#$alliance->{$type} = prettyValue($alliance->{$type});
			next unless defined $alliance->{"${type}_gain_day"};
			$alliance->{"${type}img"} = 'stay';
			$alliance->{"${type}img"} = 'up' if $alliance->{"${type}_gain_day"} > 0;
			$alliance->{"${type}img"} = 'down' if $alliance->{"${type}_gain_day"} < 0;
			if( $type eq 'size' || $type eq 'score'){
				$alliance->{"${type}rankimg"} = 'stay';
				$alliance->{"${type}rankimg"} = 'up' if $alliance->{"${type}rank_gain_day"} < 0;
				$alliance->{"${type}rankimg"} = 'down' if $alliance->{"${type}rank_gain_day"} > 0;
			}
			for my $type ($type,"${type}_gain","${type}_gain_day"){
				$alliance->{$type} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
			}
		}
		$i++;
		$alliance->{ODD} = $i % 2;
		push @alliances,$alliance;
	}
	$BODY->param(Alliances => \@alliances);
	$BODY->param(Error => $error);
	return $BODY;
}

1;
