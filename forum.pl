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
our $ERROR;


my $board;
if(param('b')){
my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post
FROM forum_boards fb NATURAL JOIN forum_access fa
WHERE fb.fbid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
	WHERE uid = $2))
GROUP BY fb.fbid,fb.board});
	$board = $DBH->selectrow_hashref($boards,undef,param('b'),$ND::UID) or $ERROR .= p($DBH->errstr);
}

my $thread;
my $findThread = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject, bool_or(fa.post) AS post
FROM forum_boards fb NATURAL JOIN forum_access fa NATURAL JOIN forum_threads ft
WHERE ft.ftid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
	WHERE uid = $2))
GROUP BY ft.ftid,ft.subject});
if(param('t')){
	$thread = $DBH->selectrow_hashref($findThread,undef,param('t'),$ND::UID) or $ERROR .= p($DBH->errstr);
}

if (defined param('cmd') && param('cmd') eq 'submit'){
	$DBH->begin_work;
	if ($board && $board->{post}){
		my $insert = $DBH->prepare(q{INSERT INTO forum_threads (fbid,subject) VALUES($1,$2)});
		if ($insert->execute($board->{id},escapeHTML(param('subject')))){
			$thread = $DBH->selectrow_hashref($findThread,undef,
				$DBH->last_insert_id(undef,undef,undef,undef,"forum_threads_ftid_seq"),$ND::UID)
				or $ERROR .= p($DBH->errstr);
		}else{
			$ERROR .= p($DBH->errstr);
		}
	}
	if ($thread && $thread->{post}){
		my $insert = $DBH->prepare(q{INSERT INTO forum_posts (ftid,message,uid) VALUES($1,$2,$3)});
		$insert->execute($thread->{id},escapeHTML(param('message')),$ND::UID) or $ERROR .= p($DBH->errstr);
	}
	$DBH->commit or $ERROR .= p($DBH->errstr);
}

my $categories = $DBH->prepare(q{SELECT fcid AS id,category FROM forum_categories ORDER BY fcid});
my $threads = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts
FROM forum_threads ft JOIN forum_posts fp USING (ftid) LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
WHERE ft.fbid = $1
GROUP BY ft.ftid, ft.subject
HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= $3});

if ($thread){ #Display the thread
	$BODY->param(Thread => 1);
	$BODY->param(Subject => $thread->{subject});
	$BODY->param(Id => $thread->{id});
	$BODY->param(Post => $thread->{post});

	my $posts = $DBH->prepare(q{SELECT u.username,date_trunc('minute',fp.time::timestamp) AS time,fp.message,COALESCE(fp.time > ftv.time,TRUE) AS unread
FROM forum_threads ft JOIN forum_posts fp USING (ftid) NATURAL JOIN users u LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
WHERE ft.ftid = $1
ORDER BY fp.time ASC
});
	$posts->execute($thread->{id},$ND::UID) or $ERROR .= p($DBH->errstr);
	my @posts;
	my $old = 1;
	while (my $post = $posts->fetchrow_hashref){
		if ($old && $post->{unread}){
			$old = 0;
			$post->{NewPosts} = 1;
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
	$threads->execute($board->{id},$ND::UID,0) or $ERROR .= p($DBH->errstr);
	my $i = 0;
	my @threads;
	while (my $thread = $threads->fetchrow_hashref){
		$i++;
		$thread->{Odd} = $i % 2;
		push @threads,$thread;
	}
	$BODY->param(Threads => \@threads);

}elsif(defined param('allUnread')){ #List threads in this board
	$BODY->param(AllUnread => 1);
	$BODY->param(Id => $board->{id});
	$categories->execute or $ERROR .= p($DBH->errstr);
	my @categories;
	my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post
FROM forum_boards fb NATURAL JOIN forum_access fa
WHERE fb.fcid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
	WHERE uid = $2))
GROUP BY fb.fbid,fb.board
});
	while (my $category = $categories->fetchrow_hashref){
		$boards->execute($category->{id},$ND::UID) or $ERROR .= p($DBH->errstr);
		my @boards;
		while (my $board = $boards->fetchrow_hashref){
			$threads->execute($board->{id},$ND::UID,1) or $ERROR .= p($DBH->errstr);
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

}else{ #List boards
	$BODY->param(Overview => 1);
	$categories->execute or $ERROR .= p($DBH->errstr);
my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board,count(NULLIF(COALESCE(fp.fpid::boolean,FALSE) AND COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread
FROM forum_boards fb NATURAL JOIN forum_access fa LEFT OUTER JOIN (forum_threads ft JOIN forum_posts fp USING (ftid)) ON fb.fbid = ft.fbid LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
WHERE fb.fcid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
		WHERE uid = $2))
GROUP BY fb.fbid, fb.board
ORDER BY fb.fbid	});
	my @categories;
	while (my $category = $categories->fetchrow_hashref){
		$boards->execute($category->{id},$ND::UID) or $ERROR .= p($DBH->errstr);
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

1;

