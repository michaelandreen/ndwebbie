package NDWeb::Controller::Intel;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Intel - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path : Args(0) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $ticks = $c->req->param('ticks') || 48;
	$c->stash(showticks => $ticks);

	my $query = $dbh->prepare(intelquery q{
			o.alliance AS oalliance ,coords(o.x,o.y,o.z) AS ocoords, i.sender
			,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords, i.target
		},q{not ingal
			AND ((( t.alliance_id != o.alliance_id OR t.alliance_id IS NULL OR o.alliance_id IS NULL) AND (i.mission = 'Defend' OR i.mission = 'AllyDef' ))
			OR ( t.alliance_id = o.alliance_id AND i.mission = 'Attack'))
			AND i.sender NOT IN (SELECT planet FROM users u NATURAL JOIN groupmembers gm WHERE gid = 8 AND planet IS NOT NULL)
			AND NOT (i.back IS NOT NULL AND i.back = i.tick + 4)
			AND i.tick > (tick() - $1)
		});
	$query->execute($ticks);
	$c->stash(intel => $query->fetchall_arrayref({}) );

	if (defined $c->req->param('coords')){
		my $coords = $c->req->param('coords');
		my @coords;
		while ($coords =~ m/(\d+:\d+:\d+)/g){
			push @coords,$1;
		}
		my $planets = $dbh->prepare(q{SELECT id,coords(x,y,z), alliance
			FROM current_planet_stats p
			WHERE coords(x,y,z) = ANY($1)
			ORDER BY alliance, p.x, p.y, p.z
		});
		$planets->execute(\@coords);
		$c->stash(coordslist => $planets->fetchall_arrayref({}) );
	}
}

sub planet : Local {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	$c->forward('findPlanet');
	my $p = $c->stash->{p};

	$c->stash(checkcoords => "$p->{x}:$p->{y}:$p->{z}");
	my $ticks = $c->req->param('ticks') || 48;
	$c->stash(showticks => $ticks);

	my $query = $dbh->prepare(q{SELECT id,coords(x,y,z),alliance,nick,channel
		FROM current_planet_stats WHERE channel ILIKE ?
		ORDER BY alliance,x,y,z
		});
	$query->execute($p->{channel});
	$c->stash(channelusers => $query->fetchall_arrayref({}) );

	$c->forward('/listAlliances');
	$c->forward('/forum/findPosts',[$p->{ftid}]);

	$c->stash(govs => ["","Feu", "Dic", "Dem","Uni"]);
	$c->stash(planetstatus => ["","Friendly", "NAP", "Hostile"]);

	$query = $dbh->prepare(intelquery q{i.sender
			,o.alliance AS oalliance,coords(o.x,o.y,o.z) AS ocoords
		},q{i.target = $1 AND i.tick > (tick() - $2)});
	$query->execute($id,$ticks);
	$c->stash(incoming => $query->fetchall_arrayref({}) );

	$query = $dbh->prepare(intelquery q{i.target
			,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords
		},q{i.sender = $1 AND i.tick > (tick() - $2)});
	$query->execute($id,$ticks);
	$c->stash(outgoing => $query->fetchall_arrayref({}) );

}

sub postplanetcomment : Local {
	my ($self, $c, $p) = @_;

	$c->forward('findPlanet');
	$p = $c->stash->{p};

	$c->forward('/forum/insertPost',[$p->{ftid}]);
	$c->res->redirect($c->uri_for('planet',$p->{id}));
}

sub postplanetupdate : Local {
	my ($self, $c, $p) = @_;
	my $dbh = $c->model;

	$c->forward('findPlanet');
	$p = $c->stash->{p};

	$dbh->begin_work;
	my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message)
		VALUES($2,$1,$3)
		});
	if ($c->req->param('cnick')){
		my $value = html_escape $c->req->param('nick');
		$dbh->do(q{UPDATE planets SET nick = ? WHERE id =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set nick to: $value");
	}
	if ($c->req->param('cchannel')){
		my $value = html_escape $c->req->param('channel');
		$dbh->do(q{UPDATE planets SET channel = ? WHERE id =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set channel to: $value");
	}
	if ($c->req->param('cstatus')){
		my $value = $c->req->param('status');
		$dbh->do(q{UPDATE planets SET planet_status = ? WHERE id =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set planet_status to: $value");
	}
	if ($c->req->param('cgov')){
		my $value = $c->req->param('gov');
		$dbh->do(q{UPDATE planets SET gov = ? WHERE id =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set gov to: $value");
	}
	if ($c->req->param('calliance')){
		my $value = $c->req->param('alliance');
		$dbh->do(q{UPDATE planets SET alliance_id = NULLIF(?,-1) WHERE id =?}
			,undef,$value,$p->{id});
		$log->execute($c->user->id,$p->{ftid},"Set alliance_id to: $value");
	}
	$dbh->commit;

	$c->res->redirect($c->uri_for('planet',$p->{id}));
}


sub find : Local {
	my ( $self, $c, $find ) = @_;
	my $dbh = $c->model;

	local $_ = $find || $c->req->param('coords');

	if (/(\d+)(?: |:)(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?/){
		my $planet = $dbh->selectrow_array(q{SELECT planetid($1,$2,$3,$4)}
			,undef,$1,$2,$3,$4);
		$c->res->redirect($c->uri_for('planet',$planet));
	}
}

sub findPlanet : Private {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT x,y,z,id, nick, alliance,alliance_id
		, planet_status,channel,ftid,gov
		FROM current_planet_stats
		WHERE id = $1
		});
	$query->execute($id);
	$c->stash(p => $query->fetchrow_hashref);
}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
