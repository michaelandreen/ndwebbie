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

	my $query = $dbh->prepare(qq{SELECT u.uid,username,TRIM(',' FROM concat(g.groupname||',')) AS groups
		FROM users u LEFT OUTER JOIN (groupmembers gm NATURAL JOIN groups g) ON gm.uid = u.uid
		WHERE u.uid > 0
		GROUP BY u.uid,username
		ORDER BY lower(username)});
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

	my $groups = $dbh->prepare(q{SELECT g.gid,g.groupname,uid 
		FROM groups g 
		LEFT OUTER JOIN (SELECT gid,uid FROM groupmembers WHERE uid = ?)
			AS gm ON g.gid = gm.gid
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

		my $delgroup = $dbh->prepare(q{DELETE FROM groupmembers WHERE uid = ? AND gid = ?});
		my $addgroup = $dbh->prepare(q{INSERT INTO groupmembers (uid,gid) VALUES(?,?)});
		for my $param ($c->req->param()){
			if ($param =~ /^c:(planet|\w+_points|hostmask|info|username|email|sms)$/){
				my $column = $1;
				my $value = $c->req->param($column);
				if ($column eq 'planet'){
					if ($value eq ''){
						$value = undef;
					}elsif($value =~ /^(\d+)\D+(\d+)\D+(\d+)$/){
						($value) = $dbh->selectrow_array(q{SELECT id FROM
							current_planet_stats WHERE x = ? and y = ? and z =?}
							,undef,$1,$2,$3);
					}
				}
				$dbh->do(qq{UPDATE users SET $column = ? WHERE uid = ? }
					,undef,$value,$user->{uid});
				$log->execute($c->user->id,"HC changed $column from $c->{$column} to $value for user: $user->{uid} ($user->{username})");
			}elsif ($param =~ /^gr:(\d+)$/){
				my $query;
				if ($c->req->param($param) eq 'remove'){
					$query = $delgroup;
				}elsif($c->req->param($param) eq 'add'){
					$query = $addgroup;
				}
				if ($query){
					$query->execute($user->{uid},$1);
					my ($action,$a2) = ('added','to');
					($action,$a2) = ('removed','from') if $c->req->param($param) eq 'remove';
					$log->execute($c->user->id,"HC $action user: $user->{uid} ($user->{username}) $a2 group: $1");
				}
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
		SELECT uid,username,hostmask,CASE WHEN u.planet IS NULL THEN '' ELSE coords(x,y,z) END AS planet,attack_points,defense_points,scan_points,humor_points,info, email, sms
		FROM users u LEFT OUTER JOIN current_planet_stats p ON u.planet = p.id
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

	my $groups = $dbh->prepare(q{SELECT gid,groupname FROM groups WHERE gid > 0 ORDER BY gid});
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
