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

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::DB;

our $dbh = ND::DB::DB();

$dbh->begin_work;

my $query = $dbh->prepare(q{INSERT INTO raids (tick,waves,message)
	VALUES(tick() + 10,3,'Retal raid') RETURNING (id)});
$query->execute;
my $raid = $query->fetchrow_array;

$query->finish;

print "$raid\n";

$dbh->do(q{INSERT INTO raid_access (raid,gid) VALUES(?,2)}
	,undef,$raid);

my $addtarget = $dbh->prepare(q{INSERT INTO raid_targets(raid,planet,comment)
	VALUES($1,$2,$3)});

my $incs = $dbh->prepare(q{SELECT sender,array_accum(i.eta) AS eta,array_accum(amount) AS amount
	,array_accum(shiptype) AS type,array_accum(fleet) AS name,array_accum(c.landing_tick) AS landing
	FROM calls c
		JOIN incomings i ON i.call = c.id
	WHERe NOT c.covered AND c.landing_tick BETWEEN tick() AND tick() + 6
		AND c.landing_tick + GREATEST(i.eta,7) > tick() + 10
	GROUP BY sender
	});
$incs->execute;

while (my $inc = $incs->fetchrow_hashref){
	my $comment = '';
	for my $eta (@{$inc->{eta}}){
		my $amount = shift @{$inc->{amount}};
		my $type = shift @{$inc->{type}};
		my $name = shift @{$inc->{name}};
		my $landing = shift @{$inc->{landing}};
		my $back = $landing + $eta;
		$comment .= "$name: ETA=$eta Amount=$amount Type:'$type' Landing tick=$landing Estimated back:$back\n";
	}
	$addtarget->execute($raid,$inc->{sender},$comment);
}

$dbh->commit;
#$dbh->rollback;

$dbh->disconnect;
