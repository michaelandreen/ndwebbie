package NDWeb::Controller::Forum;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Forum - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $boards = $dbh->prepare(q{
SELECT fcid,category,fb.fbid,fb.board
	,SUM((SELECT count(*) FROM forum_posts WHERE ftid = ft.ftid
		AND COALESCE(time > ftv.time,TRUE))) AS unread
	,date_trunc('seconds',max(ft.mtime)::timestamp ) AS last_post
FROM forum_categories fc
	JOIN forum_boards fb USING (fcid)
	LEFT OUTER JOIN forum_threads ft USING (fbid)
	LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1)
		ftv USING (ftid)
WHERE fbid IN (SELECT fbid FROM forum_access
		WHERE gid IN (SELECT groups($1)))
	OR ftid IN (SELECT ftid FROM forum_priv_access
		WHERE uid = $1)
GROUP BY fcid,category,fb.fbid, fb.board
ORDER BY fcid,fb.fbid
		});
		$boards->execute($c->stash->{UID});

	my @categories;
	my $category = {fcid => 0};
	while (my $board = $boards->fetchrow_hashref){
		if ($category->{fcid} != $board->{fcid}){
			$category = {fcid => $board->{fcid}, category => $board->{category}};
			push @categories,$category;
		}
		push @{$category->{boards}},$board;
	}
	$c->stash(categories => \@categories);
}

sub allUnread : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $threads = $dbh->prepare(q{
SELECT fcid,category,fbid,board,ft.ftid,u.username,ft.subject,ft.sticky
	,(SELECT count(*) FROM forum_posts WHERE ftid = ft.ftid
		AND COALESCE(time > ftv.time,TRUE)) AS unread
	,ft.posts,date_trunc('seconds',ft.mtime::timestamp) as last_post
	,ft.ctime::DATE as posting_date
FROM forum_categories fc
	JOIN forum_boards fb USING (fcid)
	JOIN forum_threads ft USING (fbid)
	JOIN users u ON u.uid = ft.uid
	LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1)
		ftv ON ftv.ftid = ft.ftid
WHERE ft.mtime > NOW() - '50 days'::interval
	AND COALESCE(ft.mtime > ftv.time,TRUE)
	AND ft.ftid IN (SELECT ftid FROM forum_posts WHERE ftid = ft.ftid)
	AND ((fbid > 0 AND
			fb.fbid IN (SELECT fbid FROM forum_access WHERE gid IN (SELECT groups($1))))
		OR ft.ftid IN (SELECT ftid FROM forum_priv_access WHERE uid = $1))
ORDER BY fcid,fbid,sticky DESC,last_post DESC
		});

	$threads->execute($c->stash->{UID});
	my @categories;
	my $category = {fcid => 0};
	my $board = {fbid => 0};
	while (my $thread = $threads->fetchrow_hashref){
		if ($category->{fcid} != $thread->{fcid}){
			$category = {fcid => $thread->{fcid}, category => $thread->{category}};
			push @categories,$category;
		}
		if ($board->{fbid} != $thread->{fbid}){
			$board = {fbid => $thread->{fbid}, board => $thread->{board}};
			push @{$category->{boards}},$board;
		}
		delete $thread->{fcid};
		delete $thread->{fbid};
		delete $thread->{category};
		delete $thread->{board};
		push @{$board->{threads}},$thread;
	}
	$c->stash(categories => \@categories);
	$c->stash(time => $dbh->selectrow_array('SELECT now()::timestamp',undef));
}


sub search : Local {
	my ( $self, $c ) = @_;

	my $dbh = $c->model;

	my @queries;
	if ($c->req->param('search')){
		push @queries,'('.$c->req->param('search').')';
	}
	my %cat = (body => 'D', topic => 'A', author => 'B');
	for ('body','topic','author'){
		if ($c->req->param($_)){
			my @words = split /\W+/,$c->req->param($_);
			my $op = $c->req->param('all'.$_) ? '&' : '|';
			my $cat = $cat{$_};
			my $query = join " $op ", map {"$_:$cat"} @words;
			push @queries,"($query)";
		}
	}
	my $search = join ' & ', @queries;

	if ($search){
		my $posts = $dbh->prepare(q{SELECT fp.ftid,u.username,ft.subject
			,ts_headline(fp.message,to_tsquery($2)) AS headline
			,ts_rank_cd(fp.textsearch, to_tsquery($2),32) AS rank
			FROM forum_boards fb 
				JOIN forum_threads ft USING (fbid)
				JOIN forum_posts fp USING (ftid)
				JOIN users u ON fp.uid = u.uid
			WHERE (fb.fbid IN (SELECT fbid FROM forum_access
						WHERE gid IN (SELECT groups($1)))
					OR ft.ftid IN (SELECT ftid FROM forum_priv_access WHERE uid = $1)
				) AND fp.textsearch @@@ to_tsquery($2)
			ORDER BY rank DESC
		});
		eval {
			$posts->execute($c->stash->{UID},$search);
			my @posts;
			while (my $post = $posts->fetchrow_hashref){
				push @posts,$post;
			}
			$c->stash(searchresults => \@posts);
		};
		if ($@){
			$c->stash( searcherror => $dbh->errstr);
		}
	}

}


sub board : Local {
	my ( $self, $c, $board ) = @_;
	my $dbh = $c->model;

	$c->stash(time => $dbh->selectrow_array('SELECT now()::timestamp',undef));

	$c->forward('findBoard');
	$board = $c->stash->{board};
	if ( !defined $board->{fbid}){
		$c->detach('/default');
	}

	my $threads = $dbh->prepare(q{
SELECT ft.ftid,u.username,ft.subject,ft.posts, ft.sticky
	,(SELECT count(*) FROM forum_posts WHERE ftid = ft.ftid
		AND COALESCE(time > ftv.time,TRUE)) AS unread
	,ft.ctime::DATE as posting_date
	,date_trunc('seconds',ft.mtime::timestamp) as last_post
FROM forum_threads ft
	JOIN users u USING(uid)
	LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2)
		ftv ON ftv.ftid = ft.ftid
WHERE ft.posts > 0 AND ft.fbid = $1 AND (
		ft.fbid IN (SELECT fbid FROM forum_access WHERE gid IN (SELECT groups($2)))
		OR ft.ftid IN (SELECT ftid FROM forum_priv_access WHERE uid = $2)
	)
GROUP BY ft.ftid, ft.subject,ft.sticky,u.username,ft.ctime,ft.mtime,ft.posts,ftv.time
ORDER BY sticky DESC,last_post DESC
	});
	$threads->execute($board->{fbid},$c->stash->{UID});
	my @threads;
	while (my $thread = $threads->fetchrow_hashref){
		push @threads,$thread;
	}

	if ( !(defined $board->{post}) && @threads == 0){
		$c->acl_access_denied('test',$c->action,'No access to board')
	}
	$c->stash(threads => \@threads);

	$c->stash(title => "$board->{board} ($board->{category})");

	$c->forward('listModeratorBoards', [$board->{fbid}]) if $board->{moderate};
	
}

sub thread : Local {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	$c->forward('findThread');
	$thread = $c->stash->{thread};
	unless ($thread){
		$c->stash(template => 'default.tt2');
		$c->res->status(404);
		return;
	}
	my $query = $dbh->prepare(q{SELECT uid,username FROM users u
		JOIN forum_priv_access fta USING (uid) WHERE fta.ftid = $1});
	$query->execute($thread->{ftid});
	$c->stash(access => $query->fetchall_arrayref({}) );
	$c->stash(title => $thread->{subject}
		. " ($thread->{category} - $thread->{board})");
	$c->forward('findPosts');
	$c->forward('markThreadAsRead') if $c->user_exists;
	if ($c->stash->{thread}->{moderate}) {
		$c->forward('findUsers');
		$c->forward('listModeratorBoards', [$c->stash->{thread}->{fbid}]);
	}
}

sub findPosts :Private {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	my $posts = $dbh->prepare(q{
		SELECT fpid,u.uid,u.username,date_trunc('seconds',fp.time::timestamp) AS time
			,fp.message,COALESCE(fp.time > ftv.time,TRUE) AS unread
		FROM forum_threads ft
			JOIN forum_posts fp USING (ftid)
			JOIN users u ON u.uid = fp.uid
			LEFT OUTER JOIN 
				(SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
		WHERE ft.ftid = $1
		ORDER BY fp.time ASC
		});
	$posts->execute($thread,$c->stash->{UID});

	my @posts;
	while (my $post = $posts->fetchrow_hashref){
		$post->{message} = parseMarkup($post->{message});
		push @posts,$post;
	}

	$c->stash(posts => \@posts);
}


sub markBoardAsRead : Local {
	my ( $self, $c, $board, $time ) = @_;
	my $dbh = $c->model;

	$c->forward('findBoard');
	$board = $c->stash->{board};

	my $threads = $dbh->prepare(q{SELECT ft.ftid,ft.subject
			,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread
			,count(fp.fpid) AS posts, max(fp.time)::timestamp as last_post
			FROM forum_threads ft 
				JOIN forum_posts fp USING (ftid) 
				LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
			WHERE ft.fbid = $1 AND fp.time <= $3
			GROUP BY ft.ftid, ft.subject
			HAVING count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) >= 1
		});
	$threads->execute($board->{fbid},$c->user->id,$time);
	$dbh->begin_work;
	while (my $thread = $threads->fetchrow_hashref){
		$c->forward('markThreadAsRead',[$thread->{ftid}]);
	}
	$dbh->commit;
	$c->forward('/redirect');
}

sub markThreadAsRead : Private {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	my $rows = $dbh->do(q{UPDATE forum_thread_visits SET time = now() 
		WHERE uid =	$1 AND ftid = $2
		},undef,$c->user->id,$thread);
	if ($rows == 0){
		$dbh->do(q{INSERT INTO forum_thread_visits (uid,ftid)
			VALUES ($1,$2)}
			,undef,$c->user->id,$thread);
	}
}

sub markThreadAsUnread : Local {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	my ($fbid) = $dbh->selectrow_array(q{
SELECT fbid FROM forum_threads WHERE ftid = $1
		},undef, $thread);

	$dbh->do(q{
DELETE FROM forum_thread_visits WHERE uid = $1 AND ftid = $2
		}, undef, $c->user->id, $thread);
	$c->res->redirect($c->uri_for('board',$fbid));
}

sub markPostAsUnread : Local {
	my ( $self, $c, $post ) = @_;
	my $dbh = $c->model;

	my ($fbid) = $dbh->selectrow_array(q{
SELECT fbid FROM forum_threads JOIN forum_posts USING (ftid) WHERE fpid = $1
		},undef, $post);

	$dbh->do(q{
UPDATE forum_thread_visits ftv SET time = (fp.time - interval '1 second')
FROM forum_posts fp
WHERE ftv.uid = $1 AND fp.fpid = $2 AND fp.ftid = ftv.ftid
		}, undef, $c->user->id, $post);
	$c->res->redirect($c->uri_for('board',$fbid));
}

sub moveThreads : Local {
	my ( $self, $c, $board ) = @_;
	my $dbh = $c->model;

	$c->forward('findBoard',[$c->req->param('board')]);
	my $toboard = $c->stash->{board};
	unless ($toboard->{moderate}){
		$c->acl_access_denied('test',$c->action,'No moderator access for target board.')
	}

	$c->forward('findBoard');
	$board = $c->stash->{board};
	unless ($board->{moderate}){
		$c->acl_access_denied('test',$c->action,'No moderator access for source board.')
	}

	my $log = "Moved these threads:\n\n";
	$dbh->begin_work;
	my $moveThread = $dbh->prepare(q{UPDATE forum_threads SET fbid = $1 WHERE ftid = $2 AND fbid = $3});
	for my $param ($c->req->param){
		if ($param =~ /t:(\d+)/){
			$moveThread->execute($toboard->{fbid},$1,$board->{fbid});
			if ($moveThread->rows > 0){
				$log .= "$1\n";
			}
		}
	}

	$log .= "\nFrom board: $board->{board} ($board->{fbid})";
	$log .= "\nTo board: $toboard->{board} ($toboard->{fbid})";
	$dbh->do(q{INSERT INTO forum_posts (ftid,uid,message)
		VALUES((SELECT ftid FROM users WHERE uid = $1),$1,$2)
		}, undef, $c->user->id, $log);
	$dbh->commit;
	
	$c->res->redirect($c->uri_for('board',$board->{fbid}));
}

sub newThread : Local {
	my ( $self, $c, $board ) = @_;

	$c->forward('findBoard');
	$board = $c->stash->{board};

	unless ($c->stash->{board}->{post}){
		$c->acl_access_denied('test',$c->action,'No post access to board.')
	}

	$c->forward('insertThread');
	$c->forward('addPost',[$c->stash->{thread}]);
}

sub insertThread : Private {
	my ( $self, $c, $board ) = @_;
	my $dbh = $c->model;

	my $insert = $dbh->prepare(q{INSERT INTO forum_threads (ftid,fbid,subject,uid)
		VALUES(DEFAULT,$1,$2,$3) RETURNING (ftid);
		});
	$insert->execute($board,html_escape($c->req->param('subject')),$c->stash->{UID});
	$c->stash(thread => $insert->fetchrow);
	$insert->finish;
}

sub addPost : Local {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	if ($c->req->param('cmd') eq 'Submit'){
		$c->forward('findThread');
		unless ($c->stash->{thread}->{post}){
			$c->acl_access_denied('test',$c->action,'No post access to board.')
		}
		$c->forward('insertPost');
		$c->res->redirect($c->uri_for('thread',$thread));
	}elsif ($c->req->param('cmd') eq 'Preview'){
		$c->forward('thread');
		$c->forward('previewPost');
		$c->stash(template => 'forum/thread.tt2');
	}
}

sub setSticky : Local {
	my ( $self, $c, $thread, $sticky ) = @_;
	my $dbh = $c->model;

	$c->forward('findThread');
	unless ($c->stash->{thread}->{moderate}){
		$c->acl_access_denied('test',$c->action,'No moderator access to board.')
	}

	$dbh->do(q{UPDATE forum_threads SET sticky = $2 WHERE ftid = $1}
		, undef,$thread, $sticky);
	$c->res->redirect($c->uri_for('thread',$thread));
}

sub postthreadaccess : Local {
	my ( $self, $c, $thread) = @_;
	my $dbh = $c->model;

	$c->forward('findThread');
	$dbh->begin_work;
	unless ($c->stash->{thread}->{moderate}){
		$c->acl_access_denied('test',$c->action,'No moderator access to board.')
	}
	if ($c->req->param('access')){
		$c->req->parameters->{access} = [$c->req->parameters->{access}]
			unless ref $c->req->parameters->{access} eq 'ARRAY';
		my $query = $dbh->prepare(q{DELETE From forum_priv_access
			WHERE ftid = $1 AND uid = ANY ($2)});
		$query->execute($thread,$c->req->parameters->{access});
		$dbh->do(q{INSERT INTO forum_posts (ftid,uid,message)
			VALUES((SELECT ftid FROM users WHERE uid = $1),$1,$2)
			}, undef, $c->user->id
			,"Removed access on thread $thread for : @{$c->req->parameters->{access}}");
	}
	if ($c->req->param('uid')){
		$c->forward('addaccess');
	}
	$dbh->commit;
	$c->res->redirect($c->uri_for('thread',$thread));
}

sub removeownthreadaccess : Local {
	my ( $self, $c, $thread) = @_;
	my $dbh = $c->model;
	$dbh->do(q{DELETE FROM forum_priv_access WHERE uid = $1 AND ftid = $2}
		,undef,$c->user->id,$thread);
	$c->res->redirect($c->uri_for('allUnread'));
}

sub privmsg : Local {
	my ( $self, $c, $uid ) = @_;

	$uid ||= 0;
	$c->stash(uid => $uid);

	$c->forward('findUsers');
}

sub postprivmsg : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	$c->forward('insertThread',[-1999]);

	$c->req->parameters->{uid} = [$c->req->parameters->{uid}]
		unless ref $c->req->parameters->{uid} eq 'ARRAY';
	push @{$c->req->parameters->{uid}}, $c->user->id;
	$c->forward('addaccess',[$c->stash->{thread}]);

	$c->forward('addPost',[$c->stash->{thread}]);
	$dbh->commit;
}

sub addaccess : Private {
	my ( $self, $c, $thread) = @_;
	my $dbh = $c->model;

	$c->req->parameters->{uid} = [$c->req->parameters->{uid}]
		unless ref $c->req->parameters->{uid} eq 'ARRAY';
	my $query = $dbh->prepare(q{INSERT INTO forum_priv_access (ftid,uid)
		(SELECT $1,uid FROM users u WHERE uid = ANY ($2) AND NOT uid
			IN (SELECT uid FROM forum_priv_access WHERE ftid = $1))});
	$query->execute($thread,$c->req->parameters->{uid});
	$dbh->do(q{INSERT INTO forum_posts (ftid,uid,message)
		VALUES((SELECT ftid FROM users WHERE uid = $1),$1,$2)
		}, undef, $c->user->id
		,"Gave access on thread $thread to : @{$c->req->parameters->{uid}}");
}

sub findUsers : Private {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT uid,username FROM users
		WHERE uid > 0 AND uid IN (SELECT uid FROM groupmembers)
		ORDER BY username});
	$query->execute;

	$c->stash(users => $query->fetchall_arrayref({}) );
}

sub findThread : Private {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;
	my $findThread = $dbh->prepare(q{SELECT ft.ftid,ft.subject
		,COALESCE(bool_or(fa.post),true) AS post, bool_or(fa.moderate) AS moderate
		,ft.fbid,fb.board,fb.fcid,ft.sticky,fc.category
		FROM forum_boards fb
			NATURAL JOIN forum_threads ft
			NATURAL JOIN forum_categories fc
			LEFT OUTER JOIN (SELECT fa.* FROM forum_access fa
				JOIN (SELECT groups($2) AS gid) g USING (gid)
			) fa USING (fbid)
		WHERE ft.ftid = $1 AND (fa.post IS NOT NULL
			OR ft.ftid IN (SELECT ftid FROM forum_priv_access WHERE uid = $2))
		GROUP BY ft.ftid,ft.subject,ft.fbid,fb.board,fb.fcid,ft.sticky,fc.category
	});
	$thread = $dbh->selectrow_hashref($findThread,undef,$thread,$c->stash->{UID});
	$c->stash(thread => $thread);
}

sub findBoard : Private {
	my ( $self, $c, $board ) = @_;
	my $dbh = $c->model;

	my $boards = $dbh->prepare(q{SELECT fb.fbid,fb.board, bool_or(fa.post) AS post, bool_or(fa.moderate) AS moderate,fb.fcid, fc.category
			FROM forum_boards fb
				NATURAL JOIN forum_categories fc
				LEFT OUTER JOIN (SELECT * FROM forum_access
					WHERE fbid = $1 AND gid IN (SELECT groups($2))
				) fa USING (fbid)
			WHERE fb.fbid = $1
			GROUP BY fb.fbid,fb.board,fb.fcid,fc.category
		});
	$board = $dbh->selectrow_hashref($boards,undef,$board,$c->stash->{UID});

	$c->stash(board => $board);
}

sub previewPost : Private {
	my ( $self, $c) = @_;
	push @{$c->stash->{posts}}, {
		unread => 1,
		username => 'PREVIEW',
		message => parseMarkup(html_escape $c->req->param('message')),
	};
	$c->stash(previewMessage => html_escape $c->req->param('message'));
}

sub insertPost : Private {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	my $insert = $dbh->prepare(q{INSERT INTO forum_posts (ftid,message,uid)
		VALUES($1,$2,$3)});
	$insert->execute($thread,html_escape($c->req->param('message')),$c->stash->{UID});
}

sub listModeratorBoards : Private {
	my ( $self, $c, $fbid ) = @_;
	my $dbh = $c->model;

	my $categories = $dbh->prepare(q{SELECT fcid,category FROM forum_categories ORDER BY fcid});
	my $boards = $dbh->prepare(q{SELECT fb.fbid,fb.board, bool_or(fa.post) AS post
		FROM forum_boards fb NATURAL JOIN forum_access fa
		WHERE fb.fcid = $1
			AND gid IN (SELECT groups($2))
			AND moderate
		GROUP BY fb.fbid,fb.board
		ORDER BY fb.fbid
		});
	$categories->execute;
	my @categories;
	while (my $category = $categories->fetchrow_hashref){
		$boards->execute($category->{fcid},$c->stash->{UID});

		my @boards;
		while (my $b = $boards->fetchrow_hashref){
			next if ($b->{fbid} == $fbid);
			push @boards,$b;
		}
		$category->{boards} = \@boards;
		push @categories,$category if @boards;
	}
	$c->stash(categories => \@categories);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
