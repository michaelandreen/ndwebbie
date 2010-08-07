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
use CGI qw/:standard/;

use Email::Simple;
use Encode::Encoder qw(encoder);
use MIME::QuotedPrint;

use FindBin;
use lib "$FindBin::Bin/../lib";
use ND::DB;

my $dbh = ND::DB::DB();

my @text = <>;
my $text = join '',@text;

$text =~ /ndreport\+(.+?)\@ruin\.nu/;

my $user = $1;

my $email = Email::Simple->new($text);

my $body =  encoder($email->body,'ISO-8859-15')->utf8;

my $c = $dbh->prepare(q{
SELECT coords(x,y,z) FROM current_planet_stats WHERE pid = (SELECT pid FROM users WHERE username = $1)
});

my $a = $dbh->prepare(q{
SELECT race, $1 - tick() FROM current_planet_stats WHERE x = $2 AND y = $3 AND z = $4
});

my $report = $dbh->prepare(q{INSERT INTO irc_requests (channel,uid,message) VALUES('def',$1,$2)});

while($body =~ /jumpgate from (.+?), located at (\d+):(\d+):(\d+).+?our system in tick (\d+) and appears to have (\d+)/sg){
	my ($fleet, $x,$y,$z,$tick, $amount) = ($1,$2,$3,$4,$5,$6);

	my ($coords) = $dbh->selectrow_array($c, undef, $user);

	$coords //= '(no coords entered)';

	my ($race,$eta) = $dbh->selectrow_array($a,undef, $tick,$x,$y,$z);

	$report->execute(-5,"$user has incs: $coords $x:$y:$z $fleet $race $amount $eta");
}

$dbh->disconnect;

system 'killall','-USR1', 'ndbot.pl';
