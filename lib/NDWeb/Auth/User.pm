package NDWeb::Auth::User;

use strict;
use warnings;
use Data::Dumper;
use base qw/Class::Accessor::Fast Catalyst::Authentication::User/;

BEGIN {
	__PACKAGE__->mk_accessors(qw//);
	__PACKAGE__->mk_ro_accessors(qw/username id css planet _roles/);
};

sub new {
	my ( $class ) = @_;
	my $self = {
		_roles => undef,
		username => undef,
		id => undef,
		c => undef,
	};
	bless $self, $class;
	return $self;
}



sub load {
	my ($self, $authinfo, $c) = @_;
	$self->{c} = $c;
	my $dbh = $c->model;

	if (exists $authinfo->{id}){
		$self->{id} = $dbh->selectrow_array(q{
			SELECT uid FROM users WHERE lower(username) = lower(?)
		},undef,$authinfo->{id});
	}elsif (exists $authinfo->{uid}){
		$self->{id} = $authinfo->{uid};
	}
	unless($self->{id}){
		$c->logout;
		return $self
	}

	($self->{planet},$self->{username},$self->{css}) = $dbh->selectrow_array(q{
		SELECT pid,username,css FROM users WHERE uid = ?
		},undef,$self->{id}) or die $dbh->errstr;

	return $self;
}

sub supported_features {
	my $self = shift;

	return {
		password => {
			self_check => 1,
		},
		session         => 1,
		roles           => 1,
	};
}


sub roles {
	my ( $self ) = shift;

    ## shortcut if we have already retrieved them
	if (ref $self->_roles eq 'ARRAY') {
		return(@{$self->_roles});
	}
	my $dbh = $self->{c}->model;

	my $query = $dbh->prepare(q{SELECT role FROM group_roles
		WHERE gid IN (SELECT gid FROM groupmembers WHERE uid = $1)
		}) or die $dbh->errstr;

	my @roles = ();
	$query->execute($self->id);
	while (my $group = $query->fetchrow_hashref){
		push @roles,$group->{role};
	}
	$self->{_roles} = \@roles;

	return @{$self->_roles};
}

sub for_session {
	my $self = shift;

	my $userdata = {
		uid => $self->id
	};
	return $userdata;
}

sub from_session {
	my ($self, $frozenuser, $c) = @_;

	return $self->load($frozenuser, $c);
}

sub check_password {
	my ( $self, $password ) = @_;
	my $query = $self->{c}->model->prepare(q{
		SELECT uid FROM users WHERE uid = ? AND password = md5(?)
	});
	$query->execute($self->id,$password);
	if ($query->rows == 1){
		return $self;
	}
	return;
}


1;
__END__

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2, or later.

=cut
