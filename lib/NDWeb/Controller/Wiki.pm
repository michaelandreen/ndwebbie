package NDWeb::Controller::Wiki;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Text::MediawikiFormat prefix => '/wiki/';

=head1 NAME

NDWeb::Controller::Wiki - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub auto : Priate {
	my ( $self, $c ) = @_;

	$c->stash(wikiformat => \&wikiformat);
}

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;

	push @{$c->req->captures}, ('Info','Main');
	$c->forward('page');
	$c->stash(template => 'wiki/page.tt2');
}

sub page : LocalRegex(^(?:([A-Z]\w*)(?::|%3A))?([A-Z]\w*)$) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$c->forward('findPage');
	$c->acl_access_denied('test',$c->action,'No edit access for this page')
		if defined $c->stash->{page}->{view} && !$c->stash->{page}->{view};
	$c->forward('loadText');

	unless ($c->stash->{page}->{wpid}){
		$c->stash->{page}->{namespace} = $c->req->captures->[0];
		$c->stash->{page}->{name} = $c->req->captures->[1];
		$c->stash->{page}->{fullname} = ($c->stash->{page}->{namespace} ? $c->stash->{page}->{namespace}.':' : '')
			. $c->stash->{page}->{name};
		$c->stash->{page}->{post} = $dbh->selectrow_array(q{SELECT post
				FROM wiki_namespace_access
				WHERE namespace = COALESCE($1,'') AND post AND gid IN (SELECT groups($2))
			},undef,$c->stash->{page}->{namespace}, $c->stash->{UID});
	}
	$c->stash(title => $c->stash->{page}->{fullname});
}

sub edit : LocalRegex(^edit/(?:([A-Z]\w*)(?::|%3A))?([A-Z]\w*)$) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$c->forward('findPage');
	$c->acl_access_denied('test',$c->action,'No edit access for this page')
		if defined $c->stash->{page}->{edit} && !$c->stash->{page}->{edit};
	$c->forward('loadText');
	$c->forward('findNamespaces');

	unless ($c->stash->{page}->{wpid}){
		$c->acl_access_denied('test',$c->action,'No edit access for this page')
			unless @{$c->stash->{namespaces}};
		$c->stash->{page}->{namespace} = $c->req->captures->[0];
		$c->stash->{page}->{name} = $c->req->captures->[1];
	}
}

sub history : LocalRegex(^history/(?:([A-Z]\w*)(?::|%3A))?([A-Z]\w*)$) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$c->forward('findPage');

	my $query = $dbh->prepare(q{SELECT wprev,time,username,comment
		FROM wiki_page_revisions JOIN users u USING (uid)
		WHERE wpid = $1
		ORDER BY time DESC
		});
	$query->execute($c->stash->{page}->{wpid});
	$c->stash(revisions => $query->fetchall_arrayref({}) );
	$c->stash(title => 'History for ' . $c->stash->{page}->{fullname});
}

sub postedit : Local {
	my ( $self, $c, $p ) = @_;
	my $dbh = $c->model;

	eval {
		$dbh->begin_work;

		my $wpid = $c->req->param('wpid');
		if ( $wpid eq 'new'){
			unless ($c->req->param('name') =~ /([A-Z]\w*)/){
				die 'The name is not valid, start with a capital letter and only use alphanumerical characters or _ for the rest';
			}
			my $namespace = $dbh->selectrow_array(q{SELECT namespace
				FROM wiki_namespace_access
				WHERE namespace = $1 AND post AND gid IN (SELECT groups($2))
			},undef,$c->req->param('namespace'), $c->stash->{UID});

			my $query = $dbh->prepare(q{INSERT INTO wiki_pages (namespace,name) VALUES($1,$2) RETURNING wpid});
			$query->execute($namespace,$c->req->param('name'));
			$wpid = $query->fetchrow;
		}
		$c->forward('findPage',[$wpid]);
		$c->acl_access_denied('test',$c->action,'No edit access for this page')
			if defined $c->stash->{page}->{edit} && !$c->stash->{page}->{edit};

		my $query = $dbh->prepare(q{INSERT INTO wiki_page_revisions
			(wpid,parent,text,comment,uid) VALUES($1,$2,$3,$4,$5)
			RETURNING wprev
			});
		$c->req->params->{parent}||= undef;
		$query->execute($wpid,$c->req->param('parent'),$c->req->param('text')
			,$c->req->param('comment'),$c->stash->{UID});
		my $rev = $query->fetchrow;
		$dbh->do(q{UPDATE wiki_pages SET wprev = $1 WHERE wpid = $2}
			,undef,$rev,$wpid);

		$dbh->commit;
		$c->res->redirect($c->uri_for($c->stash->{page}->{fullname}));
		return;
	} if ($c->req->param('cmd') eq 'Submit');

	if ($@){
		if ($@ =~ /duplicate key value violates unique constraint "wiki_pages_namespace_key"/){
			$c->stash(error => "Page does already exist");
		}elsif ($@ =~ /value too long for type character varying\(255\)/){
			$c->stash(error => 'The name is too long, keep it to max 255 characters');
		}else{
			$c->stash(error => $@);
		}
		$dbh->rollback;
	}

	$c->forward('findPage') if $p;
	$c->forward('findNamespaces');

	$c->stash->{page}->{namespace} = $c->req->param('namespace');
	$c->stash->{page}->{name} = $c->req->param('name');

	$c->stash(text => $c->req->param('text'));
	$c->stash(template => 'wiki/edit.tt2');
}

sub search : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	if ($c->req->param('search')){
		$c->stash(search => $c->req->param('search'));
		my $queryfunc = 'plainto_tsquery';
		$queryfunc = 'to_tsquery' if $c->req->param('advsearch');
		my $posts = $dbh->prepare(q{SELECT wp.wpid,namespace,name
			,(CASE WHEN namespace <> '' THEN namespace || ':' ELSE '' END) || name AS fullname
			,ts_headline(wpr.text,}.$queryfunc.q{($2)) AS headline
			,ts_rank_cd(textsearch, }.$queryfunc.q{($2),32) AS rank
			FROM wiki_pages wp
				JOIN wiki_page_revisions wpr USING (wprev)
			WHERE (namespace IN (SELECT namespace FROM wiki_namespace_access WHERE gid IN (SELECT groups($1)))
					OR wp.wpid IN (SELECT wpid FROM wiki_page_access WHERE uid = $1))
				AND textsearch @@ }.$queryfunc.q{($2)
			ORDER BY rank DESC
		});
		eval {
			$posts->execute($c->stash->{UID},$c->req->param('search'));
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

sub findPage : Private {
	my ( $self, $c, $p ) = @_;
	my $dbh = $c->model;

	my @arguments = ($c->stash->{UID});
	my $where;
	if ($p){
		$where =  q{AND wpid = $2};
		push @arguments, $p;
	}else{
		$where = q{AND (namespace = COALESCE($2,'') AND name = $3)};
		push @arguments, @{$c->req->captures};
	}

	my $query = q{SELECT wpid,namespace,name,wprev
		,(CASE WHEN namespace <> '' THEN namespace || ':' ELSE '' END) || name AS fullname
		,bool_or(COALESCE(wpa.edit,wna.edit)) AS edit
		,bool_or(wna.post) AS post
		,bool_or(wpa.moderate OR wna.moderate) AS moderate
		,bool_or(wpa.wpid IS NOT NULL OR wna.namespace IS NOT NULL) AS view
		FROM wiki_pages wp
			LEFT OUTER JOIN (SELECT * FROM wiki_namespace_access
				WHERE gid IN (SELECT groups($1))) wna USING (namespace)
			LEFT OUTER JOIN (SELECT * FROM wiki_page_access
				WHERE uid =  $1) wpa USING (wpid)
		WHERE TRUE
	} . $where . q{ GROUP BY wpid,namespace,name,wprev};
	$query = $dbh->prepare($query);
	$query->execute(@arguments);

	my $page = $query->fetchrow_hashref;
	$c->stash(page => $page);
}

sub loadText : Private {
	my ( $self, $c, $p ) = @_;
	my $dbh = $c->model;

	my $text = $dbh->selectrow_array(q{SELECT text
		FROM wiki_page_revisions WHERE wprev = $1
		},undef,$c->stash->{page}->{wprev});
	$c->stash(text => $text);
}

sub findNamespaces : Private {
	my ( $self, $c, $p ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT namespace FROM wiki_namespaces
		WHERE namespace IN (SELECT namespace FROM wiki_namespace_access WHERE post AND gid IN (SELECT groups($1)))
		ORDER BY namespace
		});
	$query->execute($c->stash->{UID});
	$c->stash(namespaces => $query->fetchall_arrayref({}) );
}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later

=cut

1;
