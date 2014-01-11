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
my $dumps = $dbh->prepare("SELECT dump,modified FROM dumps WHERE tick = ? and type = 'planet' ORDER BY modified LIMIT 1");

my @planets;
$dumps->execute($tick);
if (@_ = $dumps->fetchrow){
	$_ = $_[0];
	$hour = (gmtime($_[1]))[2];
	my $planetid = $dbh->prepare(q{SELECT find_planet_id($1,$2,$3)});
	while (m/(\d+)\t(\d+)\t(\d+)\t\"(.*)\"\t\"(.*)\"\t(Ter|Cat|Zik|Xan|Etd)\t(\d+)\t(\d+)\t(\d+)\t(\d+)/g){
		$planetid->execute($5,$4,$6);
		my @id = $planetid->fetchrow;
		push @planets,[$tick,$id[0],$1,$2,$3,$7,$8,$9,$10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
	}
}

for my $i (8,7,5,6){
	@planets = sort {$b->[$i] <=> $a->[$i]} @planets;
	my $rank = 0;
	for my $planet (@planets) {
		$rank++;
		$planet->[$i+4] = $rank;
    }
}

my $findplanets = $dbh->prepare(q{SELECT tick,pid, x, y, z,
	size, score, value, xp,
	sizerank, scorerank, valuerank, xprank,
	size_gain, score_gain, value_gain, xp_gain,
	sizerank_gain, scorerank_gain, valuerank_gain, xprank_gain,
	size_gain_day, score_gain_day, value_gain_day, xp_gain_day,
	sizerank_gain_day, scorerank_gain_day, valuerank_gain_day, xprank_gain_day
FROM planet_stats WHERE tick = (SELECT MAX(tick) FROM planet_stats WHERE tick < $1)});
my $insert = $dbh->prepare(q{INSERT INTO planet_stats(tick,pid, x, y, z,
	size, score, value,xp,
	sizerank,scorerank,valuerank,xprank,
	size_gain, score_gain, value_gain, xp_gain,
	sizerank_gain, scorerank_gain, valuerank_gain, xprank_gain,
	size_gain_day, score_gain_day, value_gain_day, xp_gain_day,
	sizerank_gain_day, scorerank_gain_day, valuerank_gain_day, xprank_gain_day)
	VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)});
$findplanets->execute($tick) or die $dbh->errstr;
my %oldStats;
while (my @planet = $findplanets->fetchrow){
	$oldStats{$planet[1]} = \@planet;
}
my $intel = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM planets WHERE pid = $2),$1,$3)});
$dbh->do(q{DELETE FROM planet_stats WHERE tick = $1},undef,$tick);
for my $planet (@planets) {
	#print "$planet->[1]\n";
	my $oldPlanet = $oldStats{$planet->[1]};

	if ($oldPlanet){
		for my $i (1,2,3,4){
			$planet->[$i+12] = $planet->[$i+4] - $oldPlanet->[$i+4];
			$planet->[$i+16] = $planet->[$i+8] - $oldPlanet->[$i+8];
			$planet->[$i+20] = $planet->[$i+12] + $oldPlanet->[$i+20] if $hour;
			$planet->[$i+24] = $planet->[$i+16] + $oldPlanet->[$i+24] if $hour;
		}
		if (($planet->[2] != $oldPlanet->[2]) or 
			($planet->[3] != $oldPlanet->[3]) or 
			($planet->[4] != $oldPlanet->[4])){
			#print "Planet has moved from $oldPlanet[2]:$oldPlanet[3]:$oldPlanet[4] to $planet->[2]:$planet->[3]:$planet->[4]\n";
			$intel->execute(-3, $planet->[1],"Planet has moved from $oldPlanet->[2]:$oldPlanet->[3]:$oldPlanet->[4] to $planet->[2]:$planet->[3]:$planet->[4] tick $tick");
		}
	}
	#print "@{$oldPlanet}\n";
	#print "@{$planet}\n";
	$insert->execute(@{$planet}) or die $dbh->errstr;
}
$dbh->commit;
