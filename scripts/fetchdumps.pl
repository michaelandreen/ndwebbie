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
use ND::DB;

our $dbh = ND::DB::DB();

$dbh->do("SET CLIENT_ENCODING TO 'LATIN1';");

my $insert = $dbh->prepare("INSERT INTO dumps(tick,type,modified,dump) VALUES(?,?,?,?)");
my $select = $dbh->prepare("SELECT 1 FROM dumps WHERE type = ? AND modified = ?");
my $updated = 0;
for my $type ("planet","alliance","galaxy"){
	my @head = head("http://game.planetarion.com/botfiles/${type}_listing.txt");
	$select->execute($type,$head[2]);
	unless ($select->fetchrow){
		my $file = get("http://game.planetarion.com/botfiles/${type}_listing.txt");
		if (defined $file && $file =~ /Tick: (\d+)/){
			$updated = $1;
			$insert->execute($1,$type,$head[2],$file);
		}
	}
	$select->finish;
}

if ($updated){
	`/var/www/ndawn/scripts/parsealliances.pl $updated`;
	`/var/www/ndawn/scripts/parseplanets.pl $updated`;
	`/var/www/ndawn/scripts/parsegalaxies.pl $updated`;
	`/var/www/ndawn/scripts/ndrank.pl`;
	$dbh->do(q{UPDATE misc SET value = ? WHERE id = 'TICK'}, undef, $updated);
	$dbh->do(q{VACUUM ANALYZE});
}


$dbh->disconnect;
