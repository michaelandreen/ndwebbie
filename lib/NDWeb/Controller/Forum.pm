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

	my $boards = $dbh->prepare(q{SELECT fcid,category,fb.fbid,fb.board
			,count(NULLIF(COALESCE(fp.fpid::BOOLEAN,FALSE)
				AND COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread
			,date_trunc('seconds',max(fp.time)::timestamp) as last_post
			FROM forum_categories
				JOIN forum_boards fb USING (fcid)
				LEFT OUTER JOIN forum_threads ft USING (fbid)
				LEFT OUTER JOIN forum_posts fp USING (ftid)
				LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1) ftv USING (ftid)
			WHERE EXISTS (SELECT fbid FROM forum_access WHERE fbid = fb.fbid AND gid IN (SELECT groups($1)))
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

	my $threads = $dbh->prepare(q{SELECT fcid,category,fbid,board,ft.ftid,u.username,ft.subject,
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
			WHERE fb.fbid IN (SELECT fbid FROM forum_access 
					WHERE gid IN (SELECT groups($1)))
				AND fp.textsearch @@@ to_tsquery($2)
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

	my $threads = $dbh->prepare(q{SELECT ft.ftid,u.username,ft.subject
		,count(NULLIF(COALESCE(fp.time > ftv.time,TRUE),FALSE)) AS unread,count(fp.fpid) AS posts
		,date_trunc('seconds',max(fp.time)::timestamp) as last_post
		,min(fp.time)::date as posting_date, ft.sticky
		FROM forum_threads ft 
			JOIN forum_posts fp USING (ftid) 
			JOIN users u ON u.uid = ft.uid
			LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $2) ftv ON ftv.ftid = ft.ftid
		WHERE ft.fbid = $1
		GROUP BY ft.ftid, ft.subject,ft.sticky,u.username
		ORDER BY sticky DESC,last_post DESC
	});
	$threads->execute($board->{fbid},$c->stash->{UID});
	my @threads;
	while (my $thread = $threads->fetchrow_hashref){
		push @threads,$thread;
	}
	$c->stash(threads => \@threads);

	if ($board->{moderate}){
		my $categories = $dbh->prepare(q{SELECT fcid,category FROM forum_categories ORDER BY fcid});
		my $boards = $dbh->prepare(q{SELECT fb.fbid,fb.board, bool_or(fa.post) AS post
			FROM forum_boards fb NATURAL JOIN forum_access fa
			WHERE fb.fcid = $1 AND
				gid IN (SELECT groups($2))
			GROUP BY fb.fbid,fb.board
			ORDER BY fb.fbid
		});
		$categories->execute;
		my @categories;
		while (my $category = $categories->fetchrow_hashref){
			$boards->execute($category->{fcid},$c->stash->{UID});

			my @boards;
			while (my $b = $boards->fetchrow_hashref){
				next if (not $b->{post} or $b->{fbid} == $board->{fbid});
				push @boards,$b;
			}
			$category->{boards} = \@boards;
			push @categories,$category if @boards;
		}
		$c->stash(categories => \@categories);
	}
}


sub thread : Local {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	$c->forward('findThread');
	$c->forward('findPosts') if $c->stash->{thread};
	$c->forward('markThreadAsRead') if $c->user_exists;
}

sub findPosts :Private {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;

	my $posts = $dbh->prepare(q{
		SELECT u.username,date_trunc('seconds',fp.time::timestamp) AS time
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
	$c->res->redirect($c->req->referer);
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

sub findThread : Private {
	my ( $self, $c, $thread ) = @_;
	my $dbh = $c->model;
	my $findThread = $dbh->prepare(q{SELECT ft.ftid,ft.subject, bool_or(fa.post) AS post
		, bool_or(fa.moderate) AS moderate,ft.fbid,fb.board,fb.fcid,ft.sticky,fc.category
		FROM forum_boards fb
			NATURAL JOIN forum_access fa
			NATURAL JOIN forum_threads ft
			NATURAL JOIN forum_categories fc
		WHERE ft.ftid = $1 AND gid IN (SELECT groups($2))
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
				NATURAL JOIN forum_access fa
				NATURAL JOIN forum_categories fc
			WHERE fb.fbid = $1 AND
				gid IN (SELECT groups($2))
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

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
