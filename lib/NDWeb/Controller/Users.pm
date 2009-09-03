package NDWeb::Controller::Users;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use ND::Include;
use Mail::Sendmail;

=head1 NAME

NDWeb::Controller::Users - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(qq{SELECT uid,username,array_to_string(array_agg(g.groupname),', ') AS groups
		FROM users u LEFT OUTER JOIN (groupmembers gm NATURAL JOIN groups g) USING (uid)
		WHERE uid > 0
		GROUP BY u.uid,username
		ORDER BY username});
	$query->execute;

	my @users;
	while (my $user = $query->fetchrow_hashref){
		push @users, $user;
	}
	$c->stash(users => \@users);
}

sub edit : Local {
	my ( $self, $c, $user ) = @_;
	my $dbh = $c->model;

	$c->forward('findUser');
	$user = $c->stash->{u};

	my $groups = $dbh->prepare(q{
SELECT g.gid,g.groupname,uid
FROM groups g
	LEFT OUTER JOIN (SELECT gid,uid FROM groupmembers WHERE uid = ?)
	AS gm USING(gid)
WHERE gid <> ''
		});
	$groups->execute($user->{uid});


	my @addgroups;
	my @remgroups;
	while (my $group = $groups->fetchrow_hashref){
		if ($group->{uid}){
			push @remgroups,$group;
		}else{
			push @addgroups,$group;
		}
	}
	$c->stash(membergroups => \@remgroups);
	$c->stash(othergroups => \@addgroups);

}

sub updateUser : Local {
	my ( $self, $c, $user ) = @_;
	my $dbh = $c->model;

	$c->forward('findUser');
	$user = $c->stash->{u};

	$dbh->begin_work;
	eval{
		my $log = $dbh->prepare(q{INSERT INTO forum_posts (ftid,uid,message) VALUES(
			(SELECT ftid FROM users WHERE uid = $1),$1,$2)
			});

		my $delgroups = $dbh->prepare(q{DELETE FROM groupmembers WHERE uid = $1 AND gid = ANY($2) });
		my $addgroups = $dbh->prepare(q{INSERT INTO groupmembers (uid,gid) (SELECT $1,unnest($2::text[]))});
		for my $param ($c->req->param()){
			if ($param =~ /^c:(planet|\w+_points|hostmask|info|username|email|sms)$/){
				my $column = $1;
				my $value = $c->req->param($column);
				if ($column eq 'planet'){
					$column = 'pid';
					if ($value eq ''){
						$value = undef;
					}elsif($value =~ /^(\d+)\D+(\d+)\D+(\d+)$/){
						($value) = $dbh->selectrow_array(q{SELECT pid FROM
							current_planet_stats WHERE x = ? and y = ? and z =?}
							,undef,$1,$2,$3);
					}
				}
				$dbh->do(qq{UPDATE users SET $column = ? WHERE uid = ? }
					,undef,$value,$user->{uid});
				$log->execute($c->user->id,"HC changed $column from $user->{$column} to $value for user: $user->{uid} ($user->{username})");
			}elsif ($param eq 'add_group'){
				my @groups = $c->req->param($param);
				$addgroups->execute($user->{uid},\@groups);
				$log->execute($c->user->id,"HC added user: $user->{uid} ($user->{username}) to groups: @groups");
			}elsif ($param eq 'remove_group'){
				my @groups = $c->req->param($param);
				$delgroups->execute($user->{uid},\@groups);
				$log->execute($c->user->id,"HC removed user: $user->{uid} ($user->{username}) from groups: @groups");
			}
		}
		$dbh->commit;
	};
	if ($@){
		$dbh->rollback;
		die $@;
	}
	$c->res->redirect($c->uri_for('edit',$user->{uid}));
}

sub findUser : Private {
	my ( $self, $c, $user ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{
SELECT uid,username,hostmask,attack_points,defense_points,scan_points,humor_points,info, email, sms
	,COALESCE(coords(x,y,z),'') AS planet, pid
FROM users u LEFT OUTER JOIN current_planet_stats p USING (pid)
WHERE uid = ?;
		});
	$user = $dbh->selectrow_hashref($query,undef,$user);

	$c->stash(u => $user);
}

sub mail : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	$c->stash(ok => $c->flash->{ok});
	$c->stash(error => $c->flash->{error});
	$c->stash(subject => $c->flash->{subject});
	$c->stash(message => $c->flash->{message});

	my $groups = $dbh->prepare(q{SELECT gid,groupname FROM groups WHERE gid <> '' ORDER BY gid});
	$groups->execute;
	my @groups;
	push @groups,{gid => -1, groupname => 'Pick a group'};
	while (my $group = $groups->fetchrow_hashref){
		push @groups,$group;
	}
	$c->stash(groups => \@groups);
}

sub postmail : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $emails = $dbh->prepare(q{SELECT email FROM users
		WHERE uid IN (SELECT uid FROM groupmembers WHERE gid = $1)
			AND email is not null});
	$emails->execute($c->req->param('group'));
	my @emails;
	while (my $email = $emails->fetchrow_hashref){
		push @emails,$email->{email};
	}

	my %mail = (
		smtp => 'ruin.nu',
		BCC      => (join ',',@emails),
		From    => 'NewDawn Command <nd@ruin.nu>',
		'Content-type' => 'text/plain; charset="UTF-8"',
		Subject => $c->req->param('subject'),
		Message => $c->req->param('message'),
	);

	if (sendmail %mail) {
		$c->flash(ok => \@emails);
	}else {
		$c->flash(error => $Mail::Sendmail::error);
		$c->flash(subject => $c->req->param('subject'));
		$c->flash(message => $c->req->param('message'));
	}

	$c->res->redirect($c->uri_for('mail'));
}

=head1 AUTHOR

Micahel Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
