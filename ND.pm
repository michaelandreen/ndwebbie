#!/usr/bin/perl -w -T
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
use Apache2::Request;
use ND::Include;
use ND::DB;
use strict;
use warnings FATAL => 'all';

sub handler {
	local $ND::r = shift;
	local $ND::req = Apache2::Request->new($ND::r, POST_MAX => "1M");
	local $ND::DBH;
	local $ND::USER;
	local $ND::UID;
	local $ND::PLANET;
	local $ND::TEMPLATE;
	local $ND::BODY;
	local $ND::TICK;
	local %ND::GROUPS;
	local $ND::PAGE = $ND::req->param('page');

	if ($ENV{'SCRIPT_NAME'} =~ /(\w+)(\.(pl|php|pm))?$/){
		$ND::PAGE = $1 unless $1 eq 'index' and $3 eq 'pl';
	}
	page();
	return Apache2::Const::OK;
}

sub page {
	our $DBH = ND::DB::DB();
	our $USER = $ENV{'REMOTE_USER'};
	my $error;# = $ND::r->param('page');

	chdir '/var/www/ndawn/code';

	our $TEMPLATE = HTML::Template->new(filename => 'templates/skel.tmpl', global_vars => 1, cache => 1);

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
	if ($ND::PAGE =~ /^(main|check|motd|points|covop|top100|launchConfirmation|addintel|defrequest|raids|editRaid|calls|intel|users|alliances|memberIntel|resources|planetNaps)$/){
		$page = $1;
	}

	our $XML = 0;
	$XML = 1 if param('xml') and $page =~ /^(raids)$/;

	our $AJAX = 1;

	my $type = 'text/html';
	if ($XML){
		$type = 'text/xml';
		$ND::TEMPLATE = HTML::Template->new(filename => "templates/xml.tmpl", cache => 1);
		$ND::BODY = HTML::Template->new(filename => "templates/${page}.xml.tmpl", cache => 1);
	}else{
		$ND::BODY = HTML::Template->new(filename => "templates/${page}.tmpl", global_vars => 1, cache => 1);
		$ND::BODY->param(PAGE => $page);
	}


	unless (my $return = do "${page}.pl"){
		$error .= "<p><b>couldn't parse $page: $@</b></p>" if $@;
		$error .= "<p><b>couldn't do $page: $!</b></p>"    unless defined $return;
		$error .= "<p><b>couldn't run $page</b></p>"       unless $return;
	}

	unless ($XML){
		my $fleetupdate = $DBH->selectrow_array('SELECT landing_tick FROM fleets WHERE uid = ? AND fleet = 0',undef,$UID);


		$TEMPLATE->param(Tick => $TICK);
		$TEMPLATE->param(isMember => (($TICK - $fleetupdate < 24) || isScanner()) && $PLANET && isMember());
		$TEMPLATE->param(isHC => isHC());
		$TEMPLATE->param(isDC => isDC());
		$TEMPLATE->param(isBC => isBC());
		$TEMPLATE->param(isIntel => isBC());
		$TEMPLATE->param(isAttacker => $ATTACKER && (!isMember() || ((($TICK - $fleetupdate < 24) || isScanner()) && $PLANET)));
		if ($ATTACKER && (!isMember() || ((($TICK - $fleetupdate < 24) || isScanner()) && $PLANET))){
			$ND::TEMPLATE->param(Targets => listTargets());
		}
		$TEMPLATE->param(Coords => param('coords') ? param('coords') : '1:1:1');
		$TEMPLATE->param(Error => $error);

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
	undef %GROUPS;
	$ND::BODY = undef;
}

1;
