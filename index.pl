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

for my $file ("db.pl","include.pl"){
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
undef our %GROUPS;
while (my ($name,$attack,$gid) = $query->fetchrow()){
	$GROUPS{$name} = $gid;
	$ATTACKER = 1 if $attack;
}


our $LOG = $DBH->prepare('INSERT INTO log (uid,text) VALUES(?,?)');

my $page = 'main';
if (param('page') =~ /^(main|check|motd|points|covop|top100|launchConfirmation|addintel|defrequest)$/){
	$page = $1;
}

print header;
$ND::BODY = HTML::Template->new(filename => "templates/${page}.tmpl");

unless (my $return = do "${page}.pl"){
	print "<p><b>couldn't parse $page: $@</b></p>" if $@;
	print "<p><b>couldn't do $page: $!</b></p>"    unless defined $return;
	print "<p><b>couldn't run $page</b></p>"       unless $return;
}

my $fleetupdate = $DBH->selectrow_array('SELECT landing_tick FROM fleets WHERE uid = ? AND fleet = 0',undef,$UID);

$TEMPLATE->param(Tick => $TICK);
$TEMPLATE->param(isMember => (($TICK - $fleetupdate < 24) || isScanner()) && $PLANET && isMember());
$TEMPLATE->param(isHC => isHC());
$TEMPLATE->param(isDC => isDC());
$TEMPLATE->param(isBC => isBC());
$TEMPLATE->param(isAttacker => $ATTACKER && (!isMember() || ((($TICK - $fleetupdate < 24) || isScanner()) && $PLANET)));
if ($ATTACKER && (!isMember() || ((($TICK - $fleetupdate < 24) || isScanner()) && $PLANET))){
	my $query = $DBH->prepare(qq{SELECT t.id, r.id AS raid, r.tick+c.wave-1 AS landingtick, released_coords, coords(x,y,z),c.launched
FROM raid_claims c
	JOIN raid_targets t ON c.target = t.id
	JOIN raids r ON t.raid = r.id
	JOIN current_planet_stats p ON t.planet = p.id
WHERE c.uid = ? AND r.tick+c.wave > ? AND r.open AND not r.removed
ORDER BY r.tick+c.wave,x,y,z});
	$query->execute($UID,$TICK);
	my @targets;
	while (my $target = $query->fetchrow_hashref){
		my $coords = "Target $target->{id}";
		$coords = $target->{coords} if $target->{released_coords};
		push @targets,{Coords => $coords, Launched => $target->{launched}, Raid => $target->{raid}
			, Target => $target->{id}, Tick => $target->{landingtick}};
	}
	$ND::TEMPLATE->param(Targets => \@targets);
}

$ND::TEMPLATE->param(BODY => $ND::BODY->output);
print $TEMPLATE->output;


$DBH->disconnect;
$DBH = undef;
$UID = undef;
$PLANET = undef;
$TEMPLATE = undef;
$TICK = undef;
%GROUPS = undef;
$ND::BODY = undef;

exit;
