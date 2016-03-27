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

$dbh->begin_work;
my $sms = $dbh->prepare(q{
SELECT * FROM sms WHERE msgid IS NULL AND status = 'Waiting' FOR UPDATE
});

my $update = $dbh->prepare(q{
UPDATE sms SET msgid = $2, status = $3, time = NOW() WHERE id = $1
});

$sms->execute;
eval{
	$dbh->pg_savepoint('sms') or die "Couldn't save";
	while(my $msg = $sms->fetchrow_hashref){
		$dbh->pg_release('sms') or die "Couldn't save";
		$dbh->pg_savepoint('sms') or die "Couldn't save";

		my %tags = (%tags,
			to => $msg->{number},
			text => encode("latin1",$msg->{message}),
		);

		my $res = $ua->request(
			POST 'http://api.clickatell.com/http/sendmsg',
			Content_Type  => 'application/x-www-form-urlencoded',
			Content       => [ %tags ]
		);

		given ($res->content){
			when(/^ID: (\S+)/){
				$update->execute($msg->{id},$1,'Sent');
			}
			when(/^ERR: (?:302|128|114|113|105),(.*)/){
				$update->execute($msg->{id},undef,$1);
			}
			default {
				die $_;
			}
		}
	}
};

if ($@){
	warn $@;
	$dbh->pg_rollback_to('sms') or die "rollback didn't work";
}

$dbh->commit;
