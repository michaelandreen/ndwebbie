#!/usr/bin/perl -w

use strict;
use warnings;
use DBI;
use DBD::Pg qw(:pg_types);

use LWP::Simple;
use lib qw{/var/www/ndawn/};
use ND::DB;

our $dbh = ND::DB::DB();

#$dbh->trace("0","/tmp/scanstest");
my $update = $dbh->prepare("UPDATE users SET hostmask = pnick || '.users.netgamers.org' where hostmask ilike '%.%' AND NOT hostmask ilike pnick || '.users.netgamers.org'");
$update->execute();
$dbh->disconnect;
