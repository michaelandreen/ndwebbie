package NDWeb::Controller::JSRPC;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use DateTime::TimeZone;

=head1 NAME

NDWeb::Controller::JSRPC - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;

	$c->response->body('Matched NDWeb::Controller::JSRPC in JSRPC.');
}

sub update : Local {
	my ($self, $c, $raid, $from, $target) = @_;
	my $dbh = $c->model;

	$c->forward('/raids/findRaid');
	$raid = $c->stash->{raid};

	my $targets;;
	if ($from){
		my ($timestamp) = $dbh->selectrow_array(q{SELECT MAX(modified)::timestamp AS modified
			FROM raid_targets WHERE raid = $1},undef,$raid->{id});
		$c->stash(timestamp => $timestamp);
		$targets = $dbh->prepare(q{SELECT r.id,r.pid FROM raid_targets r
			WHERE r.raid = ? AND modified > ?
		});
		$targets->execute($raid->{id},$from);
	}elsif($target){
		$targets = $dbh->prepare(q{SELECT r.id,r.pid FROM raid_targets r
			WHERE r.raid = $1 AND r.id = $2
		});
		$targets->execute($raid->{id},$target);
	}

	my $claims =  $dbh->prepare(qq{ SELECT username,joinable,launched FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ?});
	my @targets;
	while (my $target = $targets->fetchrow_hashref){
		my %target;
		$target{id} = $target->{id};
		my @waves;
		for (my $i = 1; $i <= $raid->{waves}; $i++){
			my %wave;
			$wave{id} = $i;
			$claims->execute($target->{id},$i);
			my $joinable = 0;
			my $claimers;
			if ($claims->rows != 0){
				my $owner = 0;
				my @claimers;
				while (my $claim = $claims->fetchrow_hashref){
					$owner = 1 if ($c->user->username eq $claim->{username});
					$joinable = 1 if ($claim->{joinable});
					$claim->{username} .= '*' if ($claim->{launched});
					push @claimers,$claim->{username};
				}
				$claimers = join '/', @claimers;
				if ($owner){
					$wave{command} = 'unclaim';
				}elsif ($joinable){
					$wave{command} = 'join';
				}else{
					$wave{command} = 'taken';
				}
			}else{
				$wave{command} = 'claim';
			}
			$wave{claimers} = $claimers;
			$wave{joinable} = $joinable;
			push @waves,\%wave;
		}
		$target{waves} = \@waves;
		push @targets,\%target;
	}
	$c->stash(targets => \@targets);

}

sub claim : Local {
	my ($self, $c, $raid, $from, $target, $wave) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	$c->forward('assertTarget');

	my $claims = $dbh->prepare(qq{SELECT username FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ?
		});
	$claims->execute($target,$wave);
	if ($claims->rows == 0){
		my $query = $dbh->prepare(q{INSERT INTO raid_claims (target,uid,wave) VALUES(?,?,?)});
		$query->execute($target,$c->user->id,$wave);
		$c->forward('/raids/log',[$raid, "Claimed target $target wave $wave"]);
		$c->forward('/listTargets');
	}
	$dbh->commit;

	$c->stash(template => 'jsrpc/update.tt2');
	$c->forward('update');
}


sub join : Local {
	my ($self, $c, $raid, $from, $target, $wave) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	$c->forward('assertTarget');

	my $claims = $dbh->prepare(q{SELECT username FROM raid_claims
		NATURAL JOIN users WHERE target = ? AND wave = ? AND joinable = TRUE
		});
	$claims->execute($target,$wave);
	if ($claims->rows != 0){
		my $query = $dbh->prepare(q{INSERT INTO raid_claims (target,uid,wave,joinable)
			VALUES(?,?,?,TRUE)
		});
		$query->execute($target,$c->user->id,$wave);
		$c->forward('/raids/log',[$raid, "Joined target $target wave $wave"]);
		$c->forward('/listTargets');
	}
	$dbh->commit;

	$c->stash(template => 'jsrpc/update.tt2');
	$c->forward('update');
}

sub unclaim : Local {
	my ($self, $c, $raid, $from, $target, $wave) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $query = $dbh->prepare(q{DELETE FROM raid_claims WHERE target = ?
		AND uid = ? AND wave = ?
		});
	$query->execute($target,$c->user->id,$wave);
	$c->forward('/raids/log',[$raid, "Unclaimed target $target wave $wave"]);
	$dbh->commit;

	$c->stash(template => 'jsrpc/update.tt2');
	$c->forward('/listTargets');
	$c->forward('update');
}

sub joinable : Local {
	my ($self, $c, $raid, $from, $target, $wave,$joinable) = @_;
	my $dbh = $c->model;

	my $claims = $dbh->prepare(q{SELECT username FROM raid_claims NATURAL JOIN users
		WHERE target = ? AND wave = ? AND uid = ?
		});
	$claims->execute($target,$wave,$c->user->id);
	if ($claims->rows != 0){
		my $query = $dbh->prepare(q{UPDATE raid_claims SET joinable = NOT ?
			WHERE target = ? AND wave = ?
		});
		$query->execute($joinable,$target,$wave);
	}

	$c->stash(template => 'jsrpc/update.tt2');
	$c->forward('/listTargets');
	$c->forward('update');
}

sub listTargets : Local {
	my ($self, $c) = @_;

	$c->stash(template => 'jsrpc/update.tt2');
	$c->forward('/listTargets');
}

sub tzcountries : Local {
	my ($self, $c, $cat) = @_;

	my @countries = DateTime::TimeZone->names_in_category($cat);
	$c->stash(tzcountries => \@countries);
}

sub access_denied : Private {
	my ($self, $c) = @_;
	$c->stash(template => 'jsrpc/access_denied.tt2');
	$c->res->status(403);
}

sub assertTarget : Private {
	my ($self, $c, $raid, $from, $target, $wave) = @_;
	my $dbh = $c->model;

	my $findtarget = $dbh->prepare(q{SELECT rt.id FROM raid_targets rt
		NATURAL JOIN raid_access ra NATURAL JOIN groupmembers
		WHERE uid = ? AND id = ?
		FOR UPDATE
	});

	my $result = $dbh->selectrow_array($findtarget,undef,$c->user->id,$target);
	if ($result != $target){
		$dbh->rollback;
		die 'Access denied';
	}
}

sub end : ActionClass('RenderView') {
	my ($self,$c) = @_;
	$c->res->content_type('application/xml');

	if (scalar @{ $c->error } ){
		if ($c->error->[0] =~ m/Can't call method "id" on an undefined value at/){
			$c->stash->{template} = 'jsrpc/access_denied.tt2';
			$c->res->status(403);
			$c->clear_errors;
		}elsif ($c->error->[0] =~ m/Missing roles: /){
			$c->stash->{template} = 'jsrpc/access_denied.tt2';
			$c->res->status(403);
			$c->clear_errors;
		}
	}
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later

=cut

1;
