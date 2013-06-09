#!/usr/bin/perl -w

use strict;
use warnings;
use local::lib;
use DBI;
use DBD::Pg qw(:pg_types);

use LWP::Simple;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::DB;

our $dbh = ND::DB::DB();

#$dbh->trace("0","/tmp/scanstest");
my $update = $dbh->prepare("UPDATE users SET hostmask = pnick || '.users.netgamers.org' where hostmask ilike '%.%' AND NOT hostmask ilike pnick || '.users.netgamers.org'");
$update->execute();
$dbh->disconnect;
