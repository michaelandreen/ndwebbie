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

my $thread;
if(param('t')){
	my $query = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject, bool_or(fa.post) AS post
FROM forum_boards fb NATURAL JOIN forum_access fa NATURAL JOIN forum_threads ft
WHERE ft.ftid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
	WHERE uid = $2))
GROUP BY ft.ftid,ft.subject});
	$thread = $DBH->selectrow_hashref($query,undef,param('t'),$ND::UID) or $error .= p($DBH->errstr);
}

my $board;
if(param('b')){
	my $query = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post
FROM forum_boards fb NATURAL JOIN forum_access fa
WHERE fb.fbid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
	WHERE uid = $2))
GROUP BY fb.fbid,fb.board});
	$board = $DBH->selectrow_hashref($query,undef,param('b'),$ND::UID) or $error .= p($DBH->errstr);
}

if ($thread){ #Display the thread
	$BODY->param(Thread => 1);
	$BODY->param(Subject => $thread->{subject});
	$BODY->param(Id => $thread->{id});
	$BODY->param(Post => $thread->{post});

	my $posts = $DBH->prepare(q{SELECT u.username,date_trunc('minute',fp.time::timestamp) AS time,fp.message,COALESCE(fp.time > ftv.time,TRUE) AS unread
FROM forum_threads ft JOIN forum_posts fp USING (ftid) NATURAL JOIN users u LEFT OUTER JOIN forum_thread_visits ftv ON ftv.ftid = ft.ftid
WHERE ft.ftid = $1});
	$posts->execute($thread->{id}) or $error .= p($DBH->errstr);
	my @posts;
	my $old = 1;
	while (my $post = $posts->fetchrow_hashref){
		if ($old && $post->{unread}){
			$old = 0;
			push @posts,{Username=> 'New posts', Message => '<a name="NewPosts>"/>'};
		}
		$post->{message} = parseMarkup($post->{message});
		push @posts,$post;
	}
	$BODY->param(Posts => \@posts);

	markThreadAsRead($thread->{id});

}elsif($board){ #List threads in this board
	$BODY->param(Board => $board->{board});
	$BODY->param(Post => $board->{post});
	$BODY->param(Id => $board->{id});
	my $threads = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts
FROM forum_threads ft JOIN forum_posts fp USING (ftid) LEFT OUTER JOIN forum_thread_visits ftv ON ftv.ftid = ft.ftid
WHERE ft.fbid = $1
GROUP BY ft.ftid, ft.subject});
	$threads->execute($board->{id}) or $error .= p($DBH->errstr);
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
	my $categories = $DBH->prepare(q{SELECT fcid AS id,category FROM
		forum_categories});
	my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board,count(NULLIF(COALESCE(fp.fpid::boolean,FALSE) AND COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread
FROM forum_boards fb NATURAL JOIN forum_access fa LEFT OUTER JOIN (forum_threads ft JOIN forum_posts fp USING (ftid)) ON fb.fbid = ft.fbid LEFT OUTER JOIN forum_thread_visits ftv ON ftv.ftid = ft.ftid
WHERE fb.fcid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
		WHERE uid = $2))
AND (ftv.uid IS NULL OR ftv.uid = $2)
GROUP BY fb.fbid, fb.board
		});
	$categories->execute or $error .= p($DBH->errstr);
	my @categories;
	while (my $category = $categories->fetchrow_hashref){
		$boards->execute($category->{id},$ND::UID) or $error .= p($DBH->errstr);
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
$BODY->param(Error => $error);

1;

