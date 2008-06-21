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

use lib qw{/var/www/ndawn/lib/};
use ND::DB;

our $dbh = ND::DB::DB();

$dbh->begin_work;
my $st = $dbh->prepare(q{SELECT uid FROM current_planet_stats p JOIN users u ON p.id = u.planet WHERE alliance_id = 1 ORDER BY score DESC});
my $update = $dbh->prepare(q{UPDATE users SET rank = ? WHERE uid = ?});
$st->execute;
my $rank = 1;
while (my ($uid) = $st->fetchrow){
	$update->execute($rank,$uid);
	$rank++;
}

$dbh->commit;

$dbh->disconnect;
