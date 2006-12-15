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
our $USER = $ENV{'REMOTE_USER'};

our $TEMPLATE = HTML::Template->new(filename => 'templates/skel.tmpl');

for my $file ("db.pl","include.pl"){
	unless (my $return = do $file){
		print "couldn't parse $file: $@" if $@;
		print "couldn't do $file: $!"    unless defined $return;
		print "couldn't run $file"       unless $return;
	}
}

our ($UID,$PLANET) = $DBH->selectrow_array('SELECT uid,planet FROM users WHERE username = ?'
	,undef,$ENV{'REMOTE_USER'});

our ($TICK) = $DBH->selectrow_array('SELECT tick()',undef);


my $query = $DBH->prepare('SELECT groupname,attack,gid from groupmembers NATURAL JOIN groups WHERE uid = ?');
$query->execute($UID);

our $ATTACKER = 0;
undef our %GROUPS;
while (my ($name,$attack,$gid) = $query->fetchrow()){
	$GROUPS{$name} = $gid;
	$ATTACKER = 1 if $attack;
}


our $LOG = $DBH->prepare('INSERT INTO log (uid,text) VALUES(?,?)');

my $page = 'main';
if (param('page') =~ /^(main|check|motd|points|covop|top100|launchConfirmation|addintel|defrequest|raids|editRaid|calls|intel|users)$/){
	$page = $1;
}

our $XML = 0;
$XML = 1 if param('xml') and $page =~ /^(raids)$/;

my $type = 'text/html';
if ($XML){
	$type = 'text/xml';
	$ND::TEMPLATE = HTML::Template->new(filename => "templates/xml.tmpl");
	$ND::BODY = HTML::Template->new(filename => "templates/${page}.xml.tmpl");
}else{
	$ND::BODY = HTML::Template->new(filename => "templates/${page}.tmpl");
}


unless (my $return = do "${page}.pl"){
	print "<p><b>couldn't parse $page: $@</b></p>" if $@;
	print "<p><b>couldn't do $page: $!</b></p>"    unless defined $return;
	print "<p><b>couldn't run $page</b></p>"       unless $return;
}

unless ($XML){
	my $fleetupdate = $DBH->selectrow_array('SELECT landing_tick FROM fleets WHERE uid = ? AND fleet = 0',undef,$UID);


	$TEMPLATE->param(Tick => $TICK);
	$TEMPLATE->param(isMember => (($TICK - $fleetupdate < 24) || isScanner()) && $PLANET && isMember());
	$TEMPLATE->param(isHC => isHC());
	$TEMPLATE->param(isDC => isDC());
	$TEMPLATE->param(isBC => isBC());
	$TEMPLATE->param(isAttacker => $ATTACKER && (!isMember() || ((($TICK - $fleetupdate < 24) || isScanner()) && $PLANET)));
	if ($ATTACKER && (!isMember() || ((($TICK - $fleetupdate < 24) || isScanner()) && $PLANET))){
		$ND::TEMPLATE->param(Targets => listTargets());
	}
	$TEMPLATE->param(Coords => param('coords') ? param('coords') : '1:1:1');

}
$ND::TEMPLATE->param(BODY => $ND::BODY->output);
my $output = $TEMPLATE->output;
print header(-type=> $type, -charset => 'utf-8', -Content_Length => length $output);
print $output;


$DBH->disconnect;
$DBH = undef;
$UID = undef;
$USER = undef;
$PLANET = undef;
$TEMPLATE = undef;
$TICK = undef;
%GROUPS = undef;
$ND::BODY = undef;

exit;
