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

$ND::TEMPLATE->param(TITLE => 'Forum');

our $BODY;
our $DBH;
my $error;

my %thread;
#TODO: fetch thread info.

my %board;
#TODO: fetch board info.

if (%thread){ #Display the thread
}elsif(%board){ #List threads in this board
}else{ #List boards
	$BODY->param(Overview => 1);
	my $categories = $DBH->prepare(q{SELECT fcid AS id,category FROM
		forum_categories});
	my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board
		FROM forum_boards fb NATURAL JOIN forum_access fa
		WHERE fcid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
			WHERE uid = $2))
		GROUP BY fb.fbid, fb.board
		});
	$categories->execute or $error .= p($DBH->errstr);
	my @categories;
	while (my $category = $categories->fetchrow_hashref){
		$boards->execute($category->{id},$ND::UID) or $error .= p($DBH->errstr);
		my @boards;
		my $i = 0;
		while (my $board = $boards->fetchrow_hashref){
			$board->{Unread} = 0;
			$i++;
			$board->{Odd} = $i % 2;
			push @boards,$board;
		}
		$category->{Boards} = \@boards;
		delete $category->{id};
		push @categories,$category if $i > 0;
	}
	$BODY->param(Categories => \@categories);

}
$BODY->param(Error => $error);

1;

