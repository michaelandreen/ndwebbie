#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';

no if $] >= 5.018, warnings => "experimental::smartmatch";

use local::lib;

use Encode;

use LWP::UserAgent;
use URI::Escape qw(uri_escape);
use HTTP::Request::Common;

use DBI;
use DBD::Pg qw(:pg_types);

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::DB;
my $dbh = ND::DB::DB();

my $ua = LWP::UserAgent->new(agent => 'NDWebbie' );

my $click = $dbh->selectrow_hashref(q{
SELECT api_id,username,password FROM clickatell LIMIT 1
});

my %tags = (
	api_id => $click->{api_id},
	user => $click->{username},
	password => $click->{password},
	callback => 3,
);

my $update = $dbh->prepare(q{
UPDATE clickatell SET credits = $1
});

my $res = $ua->request(
	POST 'http://api.clickatell.com/http/getbalance',
	Content_Type  => 'application/x-www-form-urlencoded',
	Content       => [ %tags ]
);

given ($res->content){
	when(/^Credit: (\d+\.\d\d)/){
		$update->execute($1);
	}
	default {
		die $_;
	}
}
