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

use strict;
use warnings FATAL => 'all';
use ND::Include;

$ND::TEMPLATE->param(TITLE => 'Edit MOTD');

our $BODY;
our $DBH;

die "You don't have access" unless isHC();

if (defined param 'cmd' and param('cmd') eq 'change'){
	$DBH->begin_work;
	my $query = $DBH->prepare(q{UPDATE misc SET value= ? WHERE id='MOTD'});
	my $motd = escapeHTML(param('motd'));
	$query->execute($motd);
	log_message $ND::UID,"Updated MOTD";
	$DBH->commit;
	$BODY->param(MOTD => $motd);
}else{
	my ($motd) = $DBH->selectrow_array(q{SELECT value FROM misc WHERE id='MOTD'});
	$BODY->param(MOTD => $motd);
}

1;
