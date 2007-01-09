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

package ND::Web::Forum;
use strict;
use warnings FATAL => 'all';
use CGI qw{:standard};
use HTML::Template;
use ND::Web::Include;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/viewForumThread addForumPost addForumThread markThreadAsRead/;

sub viewForumThread {
	my ($thread) = @_;

	my $template = HTML::Template->new(filename => "templates/viewthread.tmpl", global_vars => 1, cache => 1);

	$template->param(Subject => $thread->{subject});
	$template->param(Id => $thread->{id});
	$template->param(Post => $thread->{post});

	my $posts = $ND::DBH->prepare(q{SELECT u.username,date_trunc('minute',fp.time::timestamp) AS time,fp.message,COALESCE(fp.time > ftv.time,TRUE) AS unread
FROM forum_threads ft JOIN forum_posts fp USING (ftid) JOIN users u USING (uid) LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
WHERE ft.ftid = $1
ORDER BY fp.time ASC
});
	$posts->execute($thread->{id},$ND::UID) or $ND::ERROR .= p($ND::DBH->errstr);
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

	if (defined param('cmd') && param('cmd') eq 'Preview'){
		push @posts,{message => parseMarkup(escapeHTML(param('message'))), unread => 1, username => 'PREVIEW', Time => 'Not submitted yet', NewPosts => $old ? 1 : 0};
	}
	$template->param(Posts => \@posts);
	$template->param(Message => param('message'));

	markThreadAsRead($thread->{id});

	return $template->output;
}

sub addForumPost {
	my ($dbh,$thread,$uid,$message) = @_;
	my $insert = $dbh->prepare(q{INSERT INTO forum_posts (ftid,message,uid) VALUES($1,$2,$3)});
	unless ($insert->execute($thread->{id},escapeHTML($message),$uid)){
		$ND::ERROR .= p($dbh->errstr);
		return 0;
	}
	return 1;
}

sub addForumThread {
	my ($dbh,$board,$uid,$subject) = @_;

	my $insert = $dbh->prepare(q{INSERT INTO forum_threads (fbid,subject) VALUES($1,$2)});

	if ($insert->execute($board->{id},escapeHTML($subject))){
		my $id = $dbh->last_insert_id(undef,undef,undef,undef,"forum_threads_ftid_seq");
		return $dbh->selectrow_hashref(q{SELECT ftid AS id, subject, $2::boolean AS post FROM forum_threads WHERE ftid = $1}
			,undef,$id,$board->{post})
			or $ND::ERROR .= p($dbh->errstr);
	}else{
		$ND::ERROR .= p($dbh->errstr);
	}
}

sub markThreadAsRead {
	my ($thread) = @_;
	my $rows = $ND::DBH->do(q{UPDATE forum_thread_visits SET time = now() 
WHERE uid =	$1 AND ftid = $2},undef,$ND::UID,$thread);
	if ($rows == 0){
		$ND::DBH->do(q{INSERT INTO forum_thread_visits (uid,ftid) VALUES ($1,$2)}
			,undef,$ND::UID,$thread) or $ND::ERROR .= p($ND::DBH->errstr);
	}elsif(not defined $rows){
		$ND::ERROR .= p($ND::DBH->errstr);
	}
}

1;
