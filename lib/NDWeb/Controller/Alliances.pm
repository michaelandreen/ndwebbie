package NDWeb::Controller::Alliances;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Alliances - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	$c->stash(template => 'alliances/list.tt2');
	$c->forward('list');
}

sub list : Local {
	my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if (defined $order && $order =~ /^(score|kscore|size|ksize|members|kmem|kxp
			|kxp|scavg|kscavg|siavg|ksiavg|kxpavg|kvalue|kvalavg)$/x){
		$order = "$1 DESC";
	} else {
		$order = "score DESC";
	}
	my $query = $dbh->prepare(q{
		SELECT aid AS id,alliance AS name,COALESCE(s.score,SUM(p.score)) AS score
			,COALESCE(s.size,SUM(p.size)) AS size,s.members,count(p.score) AS kmem
			,COALESCE(SUM(p.score),-1) AS kscore
			,COALESCE(SUM(p.size),-1) AS ksize
			,COALESCE(SUM(p.xp),-1) AS kxp
			,COALESCE(SUM(p.value),-1) AS kvalue
			,COALESCE(s.score/LEAST(s.members,60),-1) AS scavg
			,COALESCE(AVG(p.score)::int,-1) AS kscavg
			,COALESCE(s.size/s.members,-1) AS siavg
			,COALESCE(AVG(p.size)::int,-1) AS ksiavg
			,COALESCE(AVG(p.xp)::int,-1) AS kxpavg
			,COALESCE(AVG(p.value)::int,-1) AS kvalavg
		FROM alliances a
			LEFT OUTER JOIN (SELECT * FROM alliance_stats
				WHERE tick = (SELECT max(tick) FROM alliance_stats)) s USING (aid)
			LEFT OUTER JOIN current_planet_stats p USING (alliance,aid)
		GROUP BY aid,alliance,s.score,s.size,s.members
		HAVING s.score IS NOT NULL OR count(p.score) > 0
		ORDER BY
		} . $order);
	$query->execute;
	$c->stash(alliances => $query->fetchall_arrayref({}) );
}

sub edit : Local {
	my ( $self, $c, $id, $order ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT aid AS id,alliance AS name, relationship FROM alliances WHERE aid = ?});
	my $a = $dbh->selectrow_hashref($query,undef,$id);
	$c->stash(a => $a);


	if ($order && $order =~ /^((score|size|value|xp|hit_us|race)(rank)?)$/){
		$order = $1;
	}else {
		$order = 'x,y,z';
	}
	$c->stash(order => $order);

	$order .= ' DESC' if $order eq 'hit_us';

	my $members = $dbh->prepare(q{
		SELECT pid AS id, coords(x,y,z), nick, ruler, planet, race, size, score, value, xp
			,planet_status,hit_us, sizerank, scorerank, valuerank, xprank
		FROM current_planet_stats p
		WHERE p.alliance = ?
		ORDER BY
		} . $order);
	$members->execute($a->{name});
	$c->stash(members => $members->fetchall_arrayref({}) );

	my $ticks = $c->req->param('ticks') || 48;
	$c->stash(showticks => $ticks);

	$query = $dbh->prepare(intelquery q{
			o.alliance AS oalliance ,coords(o.x,o.y,o.z) AS ocoords, i.sender
			,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords, i.target
		},q{NOT ingal AND (o.alliance = $1 OR t.alliance = $1)
			AND (i.mission = 'Defend' OR i.mission = 'AllyDef')
			AND COALESCE( t.alliance != o.alliance, TRUE)
			AND i.tick > (tick() - $2)
		});
	$query->execute($a->{name}, $ticks);
	$c->stash(intel => $query->fetchall_arrayref({}) );
}

sub postallianceupdate : Local {
	my ( $self, $c, $id, $order ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT aid,alliance, relationship FROM alliances WHERE aid = ?});
	my $a = $dbh->selectrow_hashref($query,undef,$id);

	$dbh->begin_work;
	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)
		});
	if ($c->req->param('crelationship')){
		my $value = $c->req->param('relationship');
		$dbh->do(q{UPDATE alliances SET relationship = ? WHERE aid =?}
			,undef,$value,$id);
		$log->execute($c->user->id
			,"HC set alliance: $a->{alliance} ($id) relationship: $value");
	}
	my $coords = $c->req->param('coords');
	my $findplanet = $dbh->prepare(q{SELECT pid FROM current_planet_stats
		WHERE x = ? AND y = ? AND z = ?});
	my $addplanet = $dbh->prepare(q{
		UPDATE planets SET alliance = $2, nick = coalesce($3,nick)
		WHERE pid = $1;
		});
	my $text = '';
	while ($coords =~ m/(\d+):(\d+):(\d+)(?:\s+nick=(\S+))?/g){
		my ($planet) = $dbh->selectrow_array($findplanet,undef,$1,$2,$3);
		$addplanet->execute($planet,$a->{alliance},$4);
		my $nick = '';
		$nick = "(nick $4)" if defined $4;
		$text .= "($planet) $1:$2:$3 $nick\n";
	}
	if ($text){
		$log->execute($c->user->id
			,"HC added the following planets to alliance $a->{alliance} ($id):\n $text");
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$id));
}

sub postremoveallplanets : Local {
	my ( $self, $c, $id, $order ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT aid,alliance, relationship FROM alliances WHERE aid = ?});
	my $a = $dbh->selectrow_hashref($query,undef,$id);

	$dbh->begin_work;
	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)
		});
	my ($coords) = $dbh->selectrow_array(q{SELECT array_to_string(array_agg(coords(x,y,z)),' ')
			FROM current_planet_stats where alliance = $1
		},undef,$a->{alliance});
	my $removeplanets = $dbh->prepare(q{
		UPDATE planets SET alliance = NULL
		WHERE alliance = $1;
	});
	$removeplanets->execute($a->{alliance});
	$log->execute($c->user->id
		,"HC cleaned alliance $a->{alliance} (id) :\n\n$coords");
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$id));
}

sub hostile : Local {
    my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	my $begintick = 0;
	my $endtick = $c->stash->{TICK};
	if ($c->req->param('ticks')){
		$begintick = $endtick - $c->req->param('ticks');
	}elsif(defined $c->req->param('begintick') && defined $c->req->param('endtick')){
		$begintick = $c->req->param('begintick');
		$endtick = $c->req->param('endtick');
	}

	my $query = $dbh->prepare(q{
		SELECT s.aid AS id,s.alliance AS name,count(*) AS hostile_count
FROM calls c 
	JOIN incomings i USING (call)
	JOIN current_planet_stats s USING (pid)
WHERE c.landing_tick - i.eta > $1 and c.landing_tick - i.eta < $2
GROUP BY s.aid,s.alliance
ORDER BY hostile_count DESC
		});
	$query->execute($begintick,$endtick);
	$c->stash(alliances => $query->fetchall_arrayref({}) );
	$c->stash(ticks => $endtick - $begintick);
	$c->stash(begin_tick => $begintick);
	$c->stash(end_tick => $endtick);
}

sub resources : Local {
    my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if (defined $order && $order =~ /^(size|score|resources|hidden|resplanet|hidplanet|nscore|nscore2|nscore3)$/){
		$order = "$1 DESC";
	}else{
		$order = "resplanet DESC";
	}

	my $query = $dbh->prepare(q{
SELECT aid AS id,alliance AS name,relationship,members,score,size
	,resources,hidden,planets
	,(resources/planets)::bigint AS resplanet
	,(hidden/planets)::bigint AS hidplanet
	, nscore, nscore2, nscore3
FROM alliance_resources
ORDER BY } . $order
	);
	$query->execute;
	$c->stash(alliances => $query->fetchall_arrayref({}));
}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
