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
use DBI;
use DBD::Pg qw(:pg_types);

use LWP::Simple;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::Include;
use ND::DB;

our $dbh = ND::DB::DB();

$ND::DBH = $dbh;

my $tick = $ARGV[0];
my $hour;
$dbh->begin_work;
my $dumps = $dbh->prepare("SELECT dump,modified FROM dumps WHERE tick = ? and type = 'galaxy' ORDER BY modified LIMIT 1");

$dumps->execute($tick);
my @galaxies;
if (@_ = $dumps->fetchrow){
	$_ = $_[0];
	$hour = (gmtime($_[1]))[2];
	while (m/(\d+)\t(\d+)\t\"(?:.+)\"\t(\d+)\t(\d+)\t(\d+)\t(\d+)/g){
		push @galaxies,[$tick,$1,$2,$3,$4,$5,$6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
	}
}

for my $i (6,5,3,4){
	@galaxies = sort {$b->[$i] <=> $a->[$i]} @galaxies;
	my $rank = 0;
	for my $galaxy (@galaxies) {
		$rank++;
		$galaxy->[$i+4] = $rank;
    }
}

my $findgalaxy = $dbh->prepare(q{SELECT tick,x, y,
	size, score, value, xp, 
	sizerank, scorerank, valuerank, xprank, 
	size_gain, score_gain, value_gain, xp_gain, 
	sizerank_gain, scorerank_gain, valuerank_gain, xprank_gain, 
	size_gain_day, score_gain_day, value_gain_day, xp_gain_day, 
	sizerank_gain_day, scorerank_gain_day, valuerank_gain_day, xprank_gain_day,
	planets,planets_gain,planets_gain_day
FROM galaxies WHERE x = $1 AND y = $2 AND tick < $3 ORDER BY tick DESC LIMIT 1});
my $insert = $dbh->prepare(q{INSERT INTO galaxies(tick, x, y,
	size, score, value,xp,
	sizerank,scorerank,valuerank,xprank,
	size_gain, score_gain, value_gain, xp_gain,
	sizerank_gain, scorerank_gain, valuerank_gain, xprank_gain,
	size_gain_day, score_gain_day, value_gain_day, xp_gain_day,
	sizerank_gain_day, scorerank_gain_day, valuerank_gain_day, xprank_gain_day,
	planets,planets_gain,planets_gain_day
	) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)});
my $countplanets = $dbh->prepare(q{SELECT count(*) from planet_stats where x = $1 and y = $2 and tick = $3});
for my $galaxy (@galaxies) {

	my ($planets) = $dbh->selectrow_array($countplanets,undef,$galaxy->[1],$galaxy->[2],$tick) or die $dbh->errstr;
	$galaxy->[27] = $planets;
	$findgalaxy->execute($galaxy->[1],$galaxy->[2],$tick) or die $dbh->errstr;
	if (my @oldGalaxy = $findgalaxy->fetchrow_array){
		for my $i (1,2,3,4){
			$galaxy->[$i+10] = $galaxy->[$i+2] - $oldGalaxy[$i+2];
			$galaxy->[$i+14] = $galaxy->[$i+6] - $oldGalaxy[$i+6];
			$galaxy->[$i+18] = $galaxy->[$i+10] + $oldGalaxy[$i+18] if $hour;
			$galaxy->[$i+22] = $galaxy->[$i+14] + $oldGalaxy[$i+22] if $hour;
		}
		$galaxy->[28] = $galaxy->[27] - $oldGalaxy[27];
		$galaxy->[29] = $galaxy->[28] + $oldGalaxy[29] if $hour;

	}
	$insert->execute(@{$galaxy}) or die $dbh->errstr;
	#print "@{$galaxy}\n";
}


#$dbh->rollback;
$dbh->commit;
