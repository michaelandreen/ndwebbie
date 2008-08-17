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
		SELECT DISTINCT a.id,name,COALESCE(s.score,SUM(p.score)) AS score
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
				WHERE tick = (SELECT max(tick) FROM alliance_stats)) s ON s.id = a.id
			LEFT OUTER JOIN current_planet_stats p ON p.alliance_id = a.id
		GROUP BY a.id,a.name,s.score,s.size,s.members
		HAVING s.score IS NOT NULL OR count(p.score) > 0
		ORDER BY
		} . $order);
	$query->execute;
	$c->stash(alliances => $query->fetchall_arrayref({}) );
	$c->stash(comma => \&comma_value);
}

sub edit : Local {
	my ( $self, $c, $id, $order ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT id,name, relationship FROM alliances WHERE id = ?});
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
		SELECT id, coords(x,y,z), nick, ruler, planet, race, size, score, value, xp
			,planet_status,hit_us, sizerank, scorerank, valuerank, xprank
		FROM current_planet_stats p
		WHERE p.alliance_id = ?
		ORDER BY
		} . $order);
	$members->execute($a->{id});
	$c->stash(members => $members->fetchall_arrayref({}) );

	my $ticks = $c->req->param('ticks') || 48;
	$c->stash(showticks => $ticks);

	$query = $dbh->prepare(intelquery q{
			o.alliance AS oalliance ,coords(o.x,o.y,o.z) AS ocoords, i.sender
			,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords, i.target
		},q{NOT ingal AND (o.alliance_id = $1 OR t.alliance_id = $1)
			AND (i.mission = 'Defend' OR i.mission = 'AllyDef')
			AND ((( t.alliance_id != o.alliance_id OR t.alliance_id IS NULL OR o.alliance_id IS NULL)))
			AND i.sender NOT IN (SELECT planet FROM users u NATURAL JOIN groupmembers gm WHERE gid = 8 AND planet IS NOT NULL)
			AND NOT (i.back IS NOT NULL AND i.back = i.tick + 4)
			AND i.tick > (tick() - $2)
		});
	$query->execute($a->{id}, $ticks);
	$c->stash(intel => $query->fetchall_arrayref({}) );
}

sub postallianceupdate : Local {
	my ( $self, $c, $id, $order ) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)
		});
	if ($c->req->param('crelationship')){
		my $value = $c->req->param('relationship');
		$dbh->do(q{UPDATE alliances SET relationship = ? WHERE id =?}
			,undef,$value,$id);
		$log->execute($c->user->id
			,"HC set alliance: $id relationship: $value");
	}
	my $coords = $c->req->param('coords');
	my $findplanet = $dbh->prepare(q{SELECT id FROM current_planet_stats
		WHERE x = ? AND y = ? AND z = ?});
	my $addplanet = $dbh->prepare(q{
		UPDATE planets SET alliance_id = $2, nick = coalesce($3,nick)
		WHERE id = $1;
		});
	my $text = '';
	while ($coords =~ m/(\d+):(\d+):(\d+)(?:\s+nick=(\S+))?/g){
		my ($planet) = $dbh->selectrow_array($findplanet,undef,$1,$2,$3);
		$addplanet->execute($planet,$id,$4);
		my $nick = '';
		$nick = "(nick $4)" if defined $4;
		$text .= "($planet) $1:$2:$3 $nick\n";
	}
	if ($text){
		$log->execute($c->user->id
			,"HC added the following planets to alliance $id:\n $text");
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('edit',$id));
}

sub postremoveallplanets : Local {
	my ( $self, $c, $id, $order ) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
		(SELECT ftid FROM users WHERE uid = $1),$1,$2)
		});
	my ($coords) = $dbh->selectrow_array(q{SELECT CONCAT(coords(x,y,z) || ' ') 
			FROM current_planet_stats where alliance_id = $1
		},undef,$id);
	my $removeplanets = $dbh->prepare(q{
		UPDATE planets SET alliance_id = NULL
		WHERE alliance_id = $1;
	});
	$removeplanets->execute($id);
	$log->execute($c->user->id
		,"HC cleaned alliance $id :\n\n$coords");
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
		SELECT s.alliance_id AS id,s.alliance AS name,count(*) AS hostile_count
FROM calls c 
	JOIN incomings i ON i.call = c.id
	JOIN current_planet_stats s ON i.sender = s.id
WHERE c.landing_tick - i.eta > $1 and c.landing_tick - i.eta < $2
GROUP BY s.alliance_id,s.alliance
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

	my $query = $dbh->prepare(qq{
		SELECT a.id,a.name,a.relationship,s.members,s.score,s.size
		,r.resources,r.hidden,r.planets
		,(resources/planets)::bigint AS resplanet
		,(hidden/planets)::bigint AS hidplanet
		,((resources / 300) + (hidden / 100))::bigint AS scoregain
		,(score + (resources / 300) + (hidden / 100))::bigint AS nscore
		,((resources/planets*scoremem)/300 + (hidden/planets*scoremem)/100)::bigint AS scoregain2
		,(score + (resources/planets*scoremem)/300
			+ (hidden/planets*scoremem)/100)::bigint AS nscore2
		,((s.size::int8*(1400-tick())*250)/100 + score + (resources/planets*scoremem)/300
			+ (hidden/planets*scoremem)/100)::bigint AS nscore3
		,(s.size::int8*(1400-tick())*250)/100 AS scoregain3
		FROM (SELECT alliance_id AS id,sum(metal+crystal+eonium) AS resources
				, sum(hidden) AS hidden, count(*) AS planets
				FROM planets p join current_planet_scans c ON p.id = c.planet
				GROUP by alliance_id
			) r
			NATURAL JOIN alliances a
			LEFT OUTER JOIN (SELECT *,LEAST(members,60) AS scoremem FROM alliance_stats
				WHERE tick = (SELECT max(tick) FROM alliance_stats)) s ON a.id = s.id
		ORDER BY $order
		});
	$query->execute;
	my @alliances;
	while (my $alliance = $query->fetchrow_hashref){
		push @alliances,$alliance;
	}
	$c->stash(alliances => \@alliances);
}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
