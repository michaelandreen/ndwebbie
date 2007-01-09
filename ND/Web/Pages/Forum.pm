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

package ND::Web::Pages::Forum;
use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use ND::Web::Forum;
use CGI qw/:standard/;
use ND::Web::Include;

$ND::PAGES{forum} = {parse => \&parse, process => \&process, render=> \&render};

sub parse {
	my ($uri) = @_;
	if ($uri =~ m{^/.*/allUnread}){
		param('allUnread',1);
	}
}

sub process {

}

sub render {
	my ($DBH,$BODY) = @_;

	$ND::TEMPLATE->param(TITLE => 'Forum');

	my $board;
	if(param('b')){
		my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post
			FROM forum_boards fb NATURAL JOIN forum_access fa
			WHERE fb.fbid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
			WHERE uid = $2))
			GROUP BY fb.fbid,fb.board});
		$board = $DBH->selectrow_hashref($boards,undef,param('b'),$ND::UID) or $ND::ERROR .= p($DBH->errstr);
	}
	if (param('markAsRead')){
		my $threads = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts, max(fp.time)::timestamp as last_post
		FROM forum_threads ft JOIN forum_posts fp USING (ftid) LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
		WHERE ((ft.fbid IS NULL AND $1 IS NULL) OR ft.fbid = $1) AND fp.time <= $3
		GROUP BY ft.ftid, ft.subject
		HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= 1
		});

		$threads->bind_param('$1',$board->{id},{TYPE => DBI::SQL_INTEGER }) or $ND::ERROR .= p($DBH->errstr);
		$threads->bind_param('$2',$ND::UID,{TYPE => DBI::SQL_INTEGER }) or $ND::ERROR .= p($DBH->errstr);
		$threads->bind_param('$3',param('markAsRead')) or $ND::ERROR .= p($DBH->errstr);
		$threads->execute or $ND::ERROR .= p($DBH->errstr);
		while (my $thread = $threads->fetchrow_hashref){
			markThreadAsRead $thread->{id};
		}
	}

	my $thread;
	my $findThread = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject, bool_or(fa.post) AS post
		FROM forum_boards fb NATURAL JOIN forum_access fa NATURAL JOIN forum_threads ft
		WHERE ft.ftid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
		WHERE uid = $2))
		GROUP BY ft.ftid,ft.subject});
	if(param('t')){
		$thread = $DBH->selectrow_hashref($findThread,undef,param('t'),$ND::UID) or $ND::ERROR .= p($DBH->errstr);
	}

	if (defined param('cmd') && param('cmd') eq 'Submit'){
		$DBH->begin_work;
		if ($board && $board->{post}){
			$thread = addForumThread $DBH,$board,$ND::UID,param('subject');
		}
		if ($thread && $thread->{post}){
			addForumPost($DBH,$thread,$ND::UID,param('message'));
		}
		$DBH->commit or $ND::ERROR .= p($DBH->errstr);
	}

	my $categories = $DBH->prepare(q{SELECT fcid AS id,category FROM forum_categories ORDER BY fcid});
	my $threads = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts, max(fp.time)::timestamp as last_post
		FROM forum_threads ft JOIN forum_posts fp USING (ftid) LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
		WHERE ft.fbid = $1
		GROUP BY ft.ftid, ft.subject
		HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= $3
		ORDER BY last_post DESC});

	if ($thread){ #Display the thread
		$BODY->param(Thread => viewForumThread $thread);

	}elsif(defined param('allUnread')){ #List threads in this board
		$BODY->param(AllUnread => 1);
		$BODY->param(Id => $board->{id});
		my ($time) = $DBH->selectrow_array('SELECT now()::timestamp',undef);
		$BODY->param(Date => $time);
		$categories->execute or $ND::ERROR .= p($DBH->errstr);
		my @categories;
		my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post
			FROM forum_boards fb NATURAL JOIN forum_access fa
			WHERE fb.fcid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
			WHERE uid = $2))
			GROUP BY fb.fbid,fb.board
			ORDER BY fb.fbid
			});
		while (my $category = $categories->fetchrow_hashref){
			$boards->execute($category->{id},$ND::UID) or $ND::ERROR .= p($DBH->errstr);
			my @boards;
			while (my $board = $boards->fetchrow_hashref){
				$threads->execute($board->{id},$ND::UID,1) or $ND::ERROR .= p($DBH->errstr);
				my $i = 0;
				my @threads;
				while (my $thread = $threads->fetchrow_hashref){
					$i++;
					$thread->{Odd} = $i % 2;
					push @threads,$thread;
				}
				$board->{Threads} = \@threads;
				delete $board->{post};
				push @boards,$board if $i > 0;
			}
			$category->{Boards} = \@boards;
			delete $category->{id};
			push @categories,$category if @boards;
		}
		$BODY->param(Categories => \@categories);

	}elsif($board){ #List threads in this board
		$BODY->param(Board => $board->{board});
		$BODY->param(Post => $board->{post});
		$BODY->param(Id => $board->{id});
		my ($time) = $DBH->selectrow_array('SELECT now()::timestamp',undef);
		$BODY->param(Date => $time);
		$threads->execute($board->{id},$ND::UID,0) or $ND::ERROR .= p($DBH->errstr);
		my $i = 0;
		my @threads;
		while (my $thread = $threads->fetchrow_hashref){
			$i++;
			$thread->{Odd} = $i % 2;
			push @threads,$thread;
		}
		$BODY->param(Threads => \@threads);

	}else{ #List boards
		$BODY->param(Overview => 1);
		$categories->execute or $ND::ERROR .= p($DBH->errstr);
		my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board,count(NULLIF(COALESCE(fp.fpid::boolean,FALSE) AND COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread
			FROM forum_boards fb LEFT OUTER JOIN (forum_threads ft JOIN forum_posts fp USING (ftid)) ON fb.fbid = ft.fbid LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
			WHERE fb.fcid = $1 AND 
			fb.fbid IN (SELECT fbid FROM forum_access WHERE gid IN (SELECT groups($2)))
			GROUP BY fb.fbid, fb.board
			ORDER BY fb.fbid	});
		my @categories;
		while (my $category = $categories->fetchrow_hashref){
			$boards->execute($category->{id},$ND::UID) or $ND::ERROR .= p($DBH->errstr);
			my @boards;
			my $i = 0;
			while (my $board = $boards->fetchrow_hashref){
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
	return $BODY;
}

1;

