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

package NDWeb::Pages::Mail;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use Mail::Sendmail;

use NDWeb::Forum;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{mail} = __PACKAGE__;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;

	my $DBH = $self->{DBH};

	$self->{TITLE} = 'Mail members';

	return $self->noAccess unless $self->isHC;

	my $groups = $DBH->prepare(q{SELECT gid,groupname FROM groups WHERE gid > 0 ORDER BY gid});
	$groups->execute;
	my @groups;
	push @groups,{gid => -1, groupname => 'Pick a group'};
	while (my $group = $groups->fetchrow_hashref){
		push @groups,$group;
	}
	$BODY->param(Groups => \@groups);

	if (defined param('cmd') && param('group') > 0){
		my $emails = $DBH->prepare(q{SELECT email FROM users
			WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = $1)
				AND email is not null});
		$emails->execute(param('group'));
		my @emails;
		while (my $email = $emails->fetchrow_hashref){
			push @emails,$email->{email};
		}
		$ND::ERROR .= p (join ', ',@emails);

		my %mail = (
			smtp => 'ruin.nu',
			BCC      => (join ',',@emails),
			From    => 'NewDawn Command <nd@ruin.nu>',
			'Content-type' => 'text/plain; charset="UTF-8"',
			Subject => param('subject'),
			Message => param('message'),
		);

		if (sendmail %mail) {
			$ND::ERROR .= p "Mail sent OK.\n" 
		}else {
			$ND::ERROR .= p $Mail::Sendmail::error;
		}
	}elsif(defined param('message')) {
		$BODY->param(Subject => param('subject'));
		$BODY->param(Message => param('message'));
	}
	return $BODY;
}
1;
