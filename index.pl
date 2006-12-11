#!/usr/bin/perl -w
#**************************************************************************
#   Copyright (C) 2006 by Michael Andreen <harvATruinDOTnu>               *
#                                                                         *
#   This program is free software; you can redistribute it and/or modify  *
#   it under the terms of the GNU General Public License as published by  *
#   the Free Software Foundation; either version 2 of the License, or     *
#   (at your option) any later version.                                   *
#                                                                         *
#   This program is distributed in the hope that it will be useful,       *
#   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
#   GNU General Public License for more details.                          *
#                                                                         *
#   You should have received a copy of the GNU General Public License     *
#   along with this program; if not, write to the                         *
#   Free Software Foundation, Inc.,                                       *
#   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.         *
#**************************************************************************/

package ND;
use CGI qw/:standard/;
use HTML::Template;
use DBI;
use DBD::Pg qw(:pg_types);
use strict;

my $cgi = new CGI;

chdir $ENV{'DOCUMENT_ROOT'};

our $DBH = undef;
our $UID = undef;
our $PLANET = undef;
our $TEMPLATE = undef;
our $TICK = undef;

$ND::TEMPLATE = HTML::Template->new(filename => 'templates/skel.tmpl');

for my $file ("db.pl"){
	unless (my $return = do $file){
		warn "couldn't parse $file: $@" if $@;
		warn "couldn't do $file: $!"    unless defined $return;
		warn "couldn't run $file"       unless $return;
	}
}

($UID,$PLANET) = $DBH->selectrow_array('SELECT uid,planet FROM users WHERE username = ?'
	,undef,$ENV{'REMOTE_USER'});

($TICK) = $DBH->selectrow_array('SELECT tick()',undef);

my $query = $DBH->prepare('SELECT groupname,attack,gid from groupmembers NATURAL JOIN groups WHERE uid = ?');
$query->execute($UID);

our $ATTACKER = 0;
our @GROUPS = ();
while (my ($name,$attack,$gid) = $query->fetchrow()){
	push @GROUPS,{name => $name, gid => $gid};
	$ATTACKER = 1 if $attack;
}


$TEMPLATE->param(Tick => $TICK);
$TEMPLATE->param(isMember => 1);
$TEMPLATE->param(isAttacker => $ATTACKER);



my $page = 'main';
if (param('page') =~ /^(main)$/){
	$page = $1;
}

$ND::BODY = HTML::Template->new(filename => "templates/${page}.tmpl");

unless (my $return = do "${page}.pl"){
	print "couldn't parse $page: $@" if $@;
	print "couldn't do $page: $!"    unless defined $return;
	print "couldn't run $page"       unless $return;
}

print header;
$ND::TEMPLATE->param(BODY => $ND::BODY->output);
print $TEMPLATE->output;


$DBH->disconnect;
$DBH = undef;
$UID = undef;
$PLANET = undef;
$TEMPLATE = undef;
$TICK = undef;
@GROUPS = undef;
$ND::BODY = undef;

exit;
