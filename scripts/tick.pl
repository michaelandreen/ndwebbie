#!/usr/bin/perl -w

use strict;
use warnings;
use DBI;
use DBD::Pg qw(:pg_types);

use LWP::Simple;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::DB;

our $dbh = ND::DB::DB();

my $update = $dbh->prepare("UPDATE misc SET value = value::int + 1 WHERE id = 'TICK'");
$update->execute();
system 'killall','-USR1', 'irssi';
$dbh->disconnect;
