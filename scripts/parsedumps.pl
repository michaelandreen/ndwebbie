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

use lib qw{/var/www/ndawn/};

use ND::Include;
use ND::DB;

our $dbh = ND::DB::DB();

$ND::DBH = $dbh;

my $tick = $ARGV[0];
my $hour;
$dbh->begin_work;
my $dumps = $dbh->prepare("SELECT dump,modified FROM dumps WHERE tick = ? and type = ? ORDER BY modified LIMIT 1");
$dumps->execute($tick,"alliance");
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
my $insert = $dbh->prepare(q{INSERT INTO alliance_stats (tick,id,members,
	size,score,
	sizerank,scorerank,
	size_gain,score_gain,
	sizerank_gain,scorerank_gain,
	size_gain_day,score_gain_day,
	sizerank_gain_day,scorerank_gain_day,
	members_gain,members_gain_day
	) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)}) or die $dbh->errstr;

my $findalliance = $dbh->prepare(q{SELECT tick,id,members,
	size, score,
	sizerank, scorerank,
	size_gain, score_gain,
	sizerank_gain, scorerank_gain,
	size_gain_day, score_gain_day,
	sizerank_gain_day, scorerank_gain_day,
	members_gain,members_gain_day
FROM alliance_stats WHERE id = $1 AND tick < $2 ORDER BY tick DESC LIMIT 1}) or die $dbh->errstr;

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

my @planets = ();
$dumps->execute($tick,"planet");
if (@_ = $dumps->fetchrow){
	$_ = $_[0];
	$hour = (gmtime($_[1]))[2];
	my $planetid = $dbh->prepare(qq{SELECT findplanetid(?,?,?)});
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

my $findplanets = $dbh->prepare(q{SELECT tick,id, x, y, z, 
	size, score, value, xp, 
	sizerank, scorerank, valuerank, xprank, 
	size_gain, score_gain, value_gain, xp_gain, 
	sizerank_gain, scorerank_gain, valuerank_gain, xprank_gain, 
	size_gain_day, score_gain_day, value_gain_day, xp_gain_day, 
	sizerank_gain_day, scorerank_gain_day, valuerank_gain_day, xprank_gain_day
FROM planet_stats WHERE tick = (SELECT MAX(tick) FROM planet_stats WHERE tick < $1)});
$insert = $dbh->prepare(q{INSERT INTO planet_stats(tick,id, x, y, z, 
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
			intel_log -3, $planet->[1],"Planet has moved from $oldPlanet->[2]:$oldPlanet->[3]:$oldPlanet->[4] to $planet->[2]:$planet->[3]:$planet->[4] tick $tick";
		}
	}
	#print "@{$oldPlanet}\n";
	#print "@{$planet}\n";
	$insert->execute(@{$planet}) or die $dbh->errstr;
}


$dumps->execute($tick,"galaxy");
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
$insert = $dbh->prepare(q{INSERT INTO galaxies(tick, x, y,
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

$countplanets->finish;
$findgalaxy->finish;
$findalliance->finish;
$dumps->finish;
$dbh->disconnect;
