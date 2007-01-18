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

package ND::Web::XMLPage;
use strict;
use warnings;
use CGI qw/:standard/;
use HTML::Template;

use ND::Include;
use ND::Web::Page;
use ND::Web::Include;

our @ISA = qw/ND::Web::Page/;

sub noAccess () {
	HTML::Template->new(filename => 'templates/NoAccess.tmpl', global_vars => 1, cache => 1);
};

sub process : method {
}

sub listTargets () : method {
	my $self = shift;
	my $DBH = $self->{DBH};
	my $query = $DBH->prepare(qq{SELECT t.id, r.id AS raid, r.tick+c.wave-1 AS landingtick, released_coords, coords(x,y,z),c.launched,c.wave,c.joinable
FROM raid_claims c
	JOIN raid_targets t ON c.target = t.id
	JOIN raids r ON t.raid = r.id
	JOIN current_planet_stats p ON t.planet = p.id
WHERE c.uid = ? AND r.tick+c.wave > ? AND r.open AND not r.removed
ORDER BY r.tick+c.wave,x,y,z});
	$query->execute($ND::UID,$self->{TICK});
	my @targets;
	while (my $target = $query->fetchrow_hashref){
		my $coords = "Target $target->{id}";
		$coords = $target->{coords} if $target->{released_coords};
		push @targets,{Coords => $coords, Launched => $target->{launched}, Raid => $target->{raid}
			, Target => $target->{id}, Tick => $target->{landingtick}, Wave => $target->{wave}
			, AJAX => $self->{AJAX}, JoinName => $target->{joinable} ? 'N' : 'J'
			, Joinable => $target->{joinable} ? 'FALSE' : 'TRUE'};
	}
	my $template = HTML::Template->new(filename => "templates/targetlist.tmpl", cache => 1);
	$template->param(Targets => \@targets);
	return $template->output;
}


sub render : method {
	my $self = shift;
	my $DBH = $self->{DBH};


	chdir '/var/www/ndawn/code';

	my $template = HTML::Template->new(filename => 'templates/skel.tmpl', global_vars => 1, cache => 1);

	my $TICK = $self->{TICK};
	my $ATTACKER = $self->{ATTACKER};

	$self->{XML} = 0;
	$self->{AJAX} = 1;

	$self->process;

	my $type = 'text/html';
	my $body;
	if ($self->{XML}){
		$type = 'text/xml';
		$template = HTML::Template->new(filename => "templates/xml.tmpl", cache => 1);
		$body = HTML::Template->new(filename => "templates/$self->{PAGE}.xml.tmpl", cache => 1);
	}else{
		$body = HTML::Template->new(filename => "templates/$self->{PAGE}.tmpl", global_vars => 1, cache => 1);
		$body->param(PAGE => $self->{PAGE});
	}

	$body = $self->render_body($body);

	unless ($self->{XML}){
		my $fleetupdate = $DBH->selectrow_array('SELECT landing_tick FROM fleets WHERE uid = ? AND fleet = 0',undef,$self->{UID});

		$fleetupdate = 0 unless defined $fleetupdate;

		my ($last_forum_visit) = $DBH->selectrow_array(q{SELECT last_forum_visit FROM users WHERE uid = $1}
			,undef,$self->{UID}) or $ND::ERROR .= p($DBH->errstr);
		my ($unread,$newposts) = $DBH->selectrow_array(unread_query(),undef,$self->{UID},$last_forum_visit)
			or $ND::ERROR .= p($DBH->errstr);
		
		$template->param(UnreadPosts => $unread);
		$template->param(NewPosts => $newposts);
		$template->param(Tick => $TICK);
		$template->param(isMember => (($TICK - $fleetupdate < 24) || $self->isScanner()) && $self->{PLANET} && $self->isMember);
		$template->param(isHC => $self->isHC);
		$template->param(isDC => $self->isDC());
		$template->param(isBC => $self->isBC());
		$template->param(isIntel => $self->isBC());
		$template->param(isAttacker => $ATTACKER && (!$self->isMember() || ((($TICK - $fleetupdate < 24) || $self->isScanner()) && $self->{PLANET})));
		if ($ATTACKER && (!$self->isMember() || ((($TICK - $fleetupdate < 24) || $self->isScanner()) && $self->{PLANET}))){
			$template->param(Targets => $self->listTargets);
		}
		$template->param(Coords => param('coords') ? param('coords') : '1:1:1');
		my ($css) = $DBH->selectrow_array(q{SELECT css FROM users WHERE uid = $1},undef,$ND::UID);
		$template->param(CSS => $css);
		$template->param(TITLE => $self->{TITLE});

	}
	$template->param(Error => $ND::ERROR);
	$template->param(BODY => $body->output);
	my $output = $template->output;
	print header(-type=> $type, -charset => 'utf-8', -Content_Length => length $output);
	print $output;


	$DBH->rollback unless $DBH->{AutoCommit};
	$DBH->disconnect;

};

1;
