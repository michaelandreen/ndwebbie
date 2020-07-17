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
use local::lib;
use DBI;
use DBD::Pg qw(:pg_types);
use CGI qw/:standard/;

use Email::Simple;
use Email::StripMIME;
use Encode;
use Encoding::FixLatin qw(fix_latin);
use MIME::QuotedPrint;

use FindBin;
use lib "$FindBin::Bin/../lib";
use ND::DB;

my $dbh = ND::DB::DB();

my @text = <>;
my $text = join '',@text;

my $email = Email::Simple->new(Email::StripMIME::strip_mime($text));;

my $subject = decode('MIME-Header', $email->header('Subject'));
my $body = 'FROM:' . decode('MIME-Header', $email->header('From')) . "\n\n" . fix_latin($email->body);


$dbh->begin_work;

my $new_thread = $dbh->prepare(q{INSERT INTO forum_threads (fbid,subject,uid) VALUES(25,$1,-4)});

if ($new_thread->execute(escapeHTML($subject))){
	my $id = $dbh->last_insert_id(undef,undef,undef,undef,"forum_threads_ftid_seq");
	my $insert = $dbh->prepare(q{INSERT INTO forum_posts (ftid,message,uid) VALUES($1,$2,-4)});
	if ($insert->execute($id,escapeHTML($body))){
		$dbh->commit;
	}else{
		print $dbh->errstr;
	}
}else{
	print $dbh->errstr;
}

$dbh->disconnect;
