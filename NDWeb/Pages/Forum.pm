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

package NDWeb::Pages::Forum;
use strict;
use warnings;
use NDWeb::Forum;
use CGI qw/:standard/;
use NDWeb::Include;
use ND::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{forum} = __PACKAGE__;

sub parse {
	my $self = shift;
	if ($self->{URI} =~ m{^/.*/allUnread}){
		$self->{allUnread} = 1;
	}elsif ($self->{URI} =~ m{^/.*/search(?:/(.*))?}){
		bless $self, 'NDWeb::Pages::Forum::Search';
		$self->{PAGE} = 'forum/search';
	}
}

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Forum';
	my $DBH = $self->{DBH};

	$DBH->do(q{UPDATE users SET last_forum_visit = NOW() WHERE uid = $1},undef,$ND::UID) or $ND::ERROR .= p($DBH->errstr);

	my $board;
	if(param('b')){
		my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post, bool_or(fa.moderate) AS moderate,fb.fcid
			FROM forum_boards fb NATURAL JOIN forum_access fa
			WHERE fb.fbid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
			WHERE uid = $2))
			GROUP BY fb.fbid,fb.board,fb.fcid});
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
	my $findThread = $DBH->prepare(q{SELECT ft.ftid AS id,ft.subject, bool_or(fa.post) AS post, bool_or(fa.moderate) AS moderate,ft.fbid,fb.board,fb.fcid,ft.sticky
		FROM forum_boards fb NATURAL JOIN forum_access fa NATURAL JOIN forum_threads ft
		WHERE ft.ftid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
		WHERE uid = $2))
		GROUP BY ft.ftid,ft.subject,ft.fbid,fb.board,fb.fcid,ft.sticky});
	if(param('t')){
		$thread = $DBH->selectrow_hashref($findThread,undef,param('t'),$ND::UID) or $ND::ERROR .= p($DBH->errstr);
	}

	if (defined param('cmd')){
		if(param('cmd') eq 'Submit' or param('cmd') eq 'Preview'){
			$DBH->begin_work;
			if ($board && $board->{post}){
				$thread = addForumThread $DBH,$board,$ND::UID,param('subject');
			}
			if (param('cmd') eq 'Submit' and $thread && $thread->{post}){
				addForumPost($DBH,$thread,$ND::UID,param('message'));
				$self->{RETURN} = 'REDIRECT';
				$self->{REDIR_LOCATION} = "/forum?t=$thread->{id}#NewPosts";
			}
			$DBH->commit or $ND::ERROR .= p($DBH->errstr);
			return if $self->{RETURN};
		}
		if(param('cmd') eq 'Move' && $board->{moderate}){
			$DBH->begin_work;
			my $moveThread = $DBH->prepare(q{UPDATE forum_threads SET fbid = $1 WHERE ftid = $2 AND fbid = $3});
			for my $param (param()){
				if ($param =~ /t:(\d+)/){
					$moveThread->execute(param('board'),$1,$board->{id}) or $ND::ERROR .= p($DBH->errstr);
					if ($moveThread->rows > 0){
						log_message $ND::UID, qq{Moved thread: $1 to board: }.param('board');
					}
				}
			}
			$DBH->commit or $ND::ERROR .= p($DBH->errstr);
		}
		if($thread && param('cmd') eq 'Sticky' && $thread->{moderate}){
			if ($DBH->do(q{UPDATE forum_threads SET sticky = TRUE WHERE ftid = ?}, undef,$thread->{id})){
				$thread->{sticky} = 1;
			}else{
				$ND::ERROR .= p($DBH->errstr);
			}
		}
		if($thread && param('cmd') eq 'Unsticky' && $thread->{moderate}){
			if ($DBH->do(q{UPDATE forum_threads SET sticky = FALSE WHERE ftid = ?}, undef,$thread->{id})){
				$thread->{sticky} = 0;
			}else{
				$ND::ERROR .= p($DBH->errstr);
			}
		}
	}

	my $categories = $DBH->prepare(q{SELECT fcid AS id,category FROM forum_categories ORDER BY fcid});
	my $boards = $DBH->prepare(q{SELECT fb.fbid AS id,fb.board, bool_or(fa.post) AS post
		FROM forum_boards fb NATURAL JOIN forum_access fa
		WHERE fb.fcid = $1 AND (gid = -1 OR gid IN (SELECT gid FROM groupmembers
		WHERE uid = $2))
		GROUP BY fb.fbid,fb.board
		ORDER BY fb.fbid
			});
	my $threads = $DBH->prepare(q{SELECT ft.ftid AS id,u.username,ft.subject,
		count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts,
		date_trunc('seconds',max(fp.time)::timestamp) as last_post,
		min(fp.time)::date as posting_date, ft.sticky
		FROM forum_threads ft JOIN forum_posts fp USING (ftid) 
			JOIN users u ON u.uid = ft.uid
			LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
		WHERE ft.fbid = $1
		GROUP BY ft.ftid, ft.subject,ft.sticky,u.username
		HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= $3
		ORDER BY sticky DESC,last_post DESC});

	if ($thread){ #Display the thread
		$BODY->param(Title =>  $thread->{subject});
		$BODY->param(FBID =>  $thread->{fbid});
		$BODY->param(Board =>  $thread->{board});
		$BODY->param(FTID =>  $thread->{id});
		$BODY->param(Moderate =>  $thread->{moderate});
		$BODY->param(Sticky =>  $thread->{sticky} ? 'Unsticky' : 'Sticky');
		$BODY->param(Thread => viewForumThread $thread);
		my ($category) = $DBH->selectrow_array(q{SELECT category FROM forum_categories WHERE fcid = $1}
			,undef,$thread->{fcid}) or $ND::ERROR .= p($DBH->errstr);
		$BODY->param(Category =>  $category);

	}elsif(defined $self->{allUnread}){ #List threads in this board
		$BODY->param(AllUnread => 1);

		my $threads = $DBH->prepare(q{SELECT fcid,category,fbid,board,ft.ftid AS id,u.username,ft.subject,
		count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts,
		date_trunc('seconds',max(fp.time)::timestamp) as last_post,
		min(fp.time)::date as posting_date, ft.sticky
		FROM forum_categories fc 
			JOIN forum_boards fb USING (fcid) 
			JOIN forum_threads ft USING (fbid)
			JOIN forum_posts fp USING (ftid) 
			JOIN users u ON u.uid = ft.uid
			LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1) ftv ON ftv.ftid = ft.ftid
		WHERE fbid > 0 AND
			fb.fbid IN (SELECT fbid FROM forum_access WHERE gid IN (SELECT groups($1)))
		GROUP BY fcid,category,fbid,board,ft.ftid, ft.subject,ft.sticky,u.username
		HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= 1 
		ORDER BY fcid,fbid,sticky DESC,last_post DESC});

		my ($time) = $DBH->selectrow_array('SELECT now()::timestamp',undef);
		$BODY->param(Date => $time);
		$threads->execute($ND::UID) or $ND::ERROR .= p($DBH->errstr);
		my @categories;
		my $category = {fcid => 0};
		my $board = {fbid => 0};
		while (my $thread = $threads->fetchrow_hashref){
			if ($category->{fcid} != $thread->{fcid}){
				delete $category->{fcid};
				$category = {fcid => $thread->{fcid}, category => $thread->{category}};
				push @categories,$category;
			}
			if ($board->{fbid} != $thread->{fbid}){
				delete $board->{fbid};
				$board = {fbid => $thread->{fbid}, board => $thread->{board}};
				push @{$category->{Boards}},$board;
			}
			delete $thread->{fcid};
			delete $thread->{fbid};
			delete $thread->{category};
			delete $thread->{board};
			push @{$board->{Threads}},$thread;
		}
		delete $category->{fcid};
		delete $board->{fbid};
		$BODY->param(Categories => \@categories);

	}elsif($board){ #List threads in this board
		$BODY->param(ViewBoard => 1);
		$BODY->param(Title => $board->{board});
		$BODY->param(Post => $board->{post});
		$BODY->param(Moderate => $board->{moderate});
		$BODY->param(Id => $board->{id});
		$BODY->param(FBID => $board->{id});
		$BODY->param(Board => $board->{board});
		my ($time) = $DBH->selectrow_array('SELECT now()::timestamp',undef);
		$BODY->param(Date => $time);
		$threads->execute($board->{id},$ND::UID,0) or $ND::ERROR .= p($DBH->errstr);
		my @threads;
		while (my $thread = $threads->fetchrow_hashref){
			push @threads,$thread;
		}
		$BODY->param(Threads => \@threads);

		if ($board->{moderate}){
			$categories->execute or $ND::ERROR .= p($DBH->errstr);
			my @categories;
			while (my $category = $categories->fetchrow_hashref){
				$boards->execute($category->{id},$ND::UID) or $ND::ERROR .= p($DBH->errstr);

				my @boards;
				while (my $b = $boards->fetchrow_hashref){
					next if (not $b->{post} or $b->{id} == $board->{id});
					delete $b->{post};
					push @boards,$b;
				}
				$category->{Boards} = \@boards;
				delete $category->{id};
				push @categories,$category if @boards;
			}
			$BODY->param(Categories => \@categories);
		}
		my ($category) = $DBH->selectrow_array(q{SELECT category FROM forum_categories WHERE fcid = $1}
			,undef,$board->{fcid}) or $ND::ERROR .= p($DBH->errstr);
		$BODY->param(Category =>  $category);
	}else{ #List boards
		$BODY->param(Overview => 1);
		my $boards = $DBH->prepare(q{SELECT fcid,category,fb.fbid AS id,fb.board
			,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread
			,date_trunc('seconds',max(fp.time)::timestamp) as last_post
			FROM forum_categories
				JOIN forum_boards fb USING (fcid)
				JOIN forum_threads ft USING (fbid)
				JOIN forum_posts fp USING (ftid)
				LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1) ftv USING (ftid)
			WHERE EXISTS (SELECT fbid FROM forum_access WHERE fbid = fb.fbid AND gid IN (SELECT groups($1)))
			GROUP BY fcid,category,fb.fbid, fb.board
			ORDER BY fcid,fb.fbid
		});
		$boards->execute($ND::UID) or warn $DBH->errstr;
		my @categories;
		my $category = {fcid => 0};
		while (my $board = $boards->fetchrow_hashref){
			if ($category->{fcid} != $board->{fcid}){
				delete $category->{fcid};
				$category = {fcid => $board->{fcid}, category => $board->{category}};
				push @categories,$category;
			}
			delete $board->{fcid};
			delete $board->{category};
			push @{$category->{Boards}},$board;
		}
		delete $category->{fcid};
		$BODY->param(Categories => \@categories);

	}
	return $BODY;
}

1;

