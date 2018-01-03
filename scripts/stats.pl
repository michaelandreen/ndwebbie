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

use LWP::Simple qw/get $ua/;
$ua->agent("Stupid user agent check is stupid");

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::DB;

our $dbh = ND::DB::DB();

$dbh->do("SET CLIENT_ENCODING TO 'LATIN1';");

my %classes = (Fighter => 'Fi', Corvette => 'Co', Frigate => 'Fr', Destroyer => 'De', Cruiser => 'Cr', Battleship => 'Bs');

my $file = get("http://game.planetarion.com/manual.pl?page=stats");
$dbh->begin_work;
my $st = $dbh->prepare(q{INSERT INTO ship_stats (ship,"class",t1,t2,t3,"type",init,guns,armor,damage,eres,metal,crystal,eonium,race) VALUES(?,?,NULLIF(?,'-'),NULLIF(?,'-'),NULLIF(?,'-'),?,?,?,?,?,?,?,?,?,?)});
while ($file =~ /class="(\w+)"><td>((?:\w| )+)<\/td><td>(\w+)<\/td><td>(\w+|-)<\/td><td>(\w+|-)<\/td><td>(\w+)\D+(\d+)\D+(\d+)\D+(\d+)\D+?(\d+|-)\D+(\d+)\D+(\d+)\D+(\d+)\D+(\d+)\D+\d+\D+\d+.+?(\w+)<\/td>/g){
	my $dmg = $10;
	$dmg = 0 if $dmg eq '-';
	my $class = $classes{$3};
	$st->execute($2,$class,$4,$5,'-',$6,$7,$8,$9,$dmg,$11,$12,$13,$14,$1) or die $dbh->errstr;
	print "$2,$class,$4,$5,'-',$6,$7,$dmg,$9,$10,$11,$12,$13,$14,$1\n";
}

$dbh->commit;

$dbh->disconnect;
