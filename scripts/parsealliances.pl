#!/usr/bin/perl
q{
/***************************************************************************
 *   Copyright (C) 2006 by Michael Andreen <harvATruinDOTnu>               *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.         *
 ***************************************************************************/
};

use strict;
use warnings;
use local::lib;
use DBI;
use DBD::Pg qw(:pg_types);

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::Include;
use ND::DB;

our $dbh = ND::DB::DB();

my $tick = $ARGV[0];
my $hour;
$dbh->begin_work;
my $dumps = $dbh->prepare("SELECT dump,modified FROM dumps WHERE tick = ? and type = 'alliance' ORDER BY modified LIMIT 1");
$dumps->execute($tick);
my @alliances;
if (@_ = $dumps->fetchrow){
	$_ = $_[0];	
	$hour = (gmtime($_[1]))[2];
	my $allianceid = $dbh->prepare(qq{SELECT find_alliance_id(?)});
	while (m/\d+\t\"(.+)\"\t(\d+)\t(\d+)\t(\d+)/g){
		$allianceid->execute($1);
		my ($id) = $allianceid->fetchrow;
		push @alliances,[$tick,$id,$3,$2,$4,0,0,0,0,0,0,0,0,0,0,0,0];
	}
}


for my $i (3,4){
	@alliances = sort {$b->[$i] <=> $a->[$i]} @alliances;
	my $rank = 0;
	for my $alliance (@alliances) {
		$rank++;
		$alliance->[$i+2] = $rank;
    }
}
my $insert = $dbh->prepare(q{INSERT INTO alliance_stats (tick,aid,members,
	size,score,
	sizerank,scorerank,
	size_gain,score_gain,
	sizerank_gain,scorerank_gain,
	size_gain_day,score_gain_day,
	sizerank_gain_day,scorerank_gain_day,
	members_gain,members_gain_day
	) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)}) or die $dbh->errstr;

my $findalliance = $dbh->prepare(q{SELECT tick,aid,members,
	size, score,
	sizerank, scorerank,
	size_gain, score_gain,
	sizerank_gain, scorerank_gain,
	size_gain_day, score_gain_day,
	sizerank_gain_day, scorerank_gain_day,
	members_gain,members_gain_day
FROM alliance_stats WHERE aid = $1 AND tick < $2 ORDER BY tick DESC LIMIT 1}) or die $dbh->errstr;

$dbh->do(q{DELETE FROM alliance_stats WHERE tick = $1},undef,$tick);

for my $alliance (@alliances) {

	$findalliance->execute($alliance->[1],$tick) or die $dbh->errstr;
	if (my @oldAlliance = $findalliance->fetchrow_array){
		for my $i (1,2){
			$alliance->[$i+6] = $alliance->[$i+2] - $oldAlliance[$i+2];
			$alliance->[$i+8] = $alliance->[$i+4] - $oldAlliance[$i+4];
			$alliance->[$i+10] = $alliance->[$i+6] + $oldAlliance[$i+10] if $hour;
			$alliance->[$i+12] = $alliance->[$i+8] + $oldAlliance[$i+12] if $hour;
		}
		$alliance->[15] = $alliance->[2] - $oldAlliance[+2];
		$alliance->[16] = $alliance->[15] + $oldAlliance[16] if $hour;

	}
	$insert->execute(@{$alliance}) or die $dbh->errstr;
}

$dbh->commit;
