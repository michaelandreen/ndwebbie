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
package ND::Web::Page;
use strict;
use warnings;
use CGI qw/:standard/;

our %PAGES;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {@_};
	$self->{PAGE} = 'main' unless (defined $self->{PAGE} and exists $PAGES{$self->{PAGE}});
	$class = $PAGES{$self->{PAGE}};
	bless $self, $class;
	$self->parse;
	$self->initiate;
	return $self;
}

sub initiate : method {
	my $self = shift;
	my $DBH = $self->{DBH};

	$DBH->do(q{SET timezone = 'GMT'});

	($self->{UID},$self->{PLANET},$self->{USER}) = $DBH->selectrow_array('SELECT uid,planet,username FROM users WHERE username ILIKE ?'
		,undef,$ENV{'REMOTE_USER'});
	$ND::UID = $self->{UID};

	($self->{TICK}) = $DBH->selectrow_array('SELECT tick()',undef);
	$self->{TICK} = 0 unless defined $self->{TICK};


	my $query = $DBH->prepare('SELECT groupname,attack,gid from groupmembers NATURAL JOIN groups WHERE uid = ?');
	$query->execute($self->{UID});

	while (my ($name,$attack,$gid) = $query->fetchrow()){
		$self->{GROUPS}{$name} = $gid;
		$self->{ATTACKER} = 1 if $attack;
	}


}

sub parse : method {
}

sub render_body : method {
	return "";
}

sub render : method {
	my $self = shift;

	print header;
	print $self->render_body;
}

sub isInGroup ($) : method {
	my $self = shift;
	my $group = shift;
	return exists $self->{GROUPS}{$group} || exists $self->{GROUPS}{Tech};
}

sub isMember () : method {
	my $self = shift;
	$self->isInGroup('Members');
}

sub isHC () : method {
	my $self = shift;
	$self->isInGroup('HC');
}

sub isDC () : method {
	$_[0]->isInGroup('DC');
}

sub isBC () : method {
	$_[0]->isInGroup('BC');
}

sub isOfficer () : method {
	$_[0]->isInGroup('Officers');
}

sub isScanner () : method {
	$_[0]->isInGroup('Scanners');
}

sub isIntel () : method {
	$_[0]->isInGroup('Intel');
}

sub isTech () : method {
	$_[0]->isInGroup('Tech');
}



1;
