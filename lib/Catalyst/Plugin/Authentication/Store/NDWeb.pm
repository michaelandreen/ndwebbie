package Catalyst::Plugin::Authentication::Store::NDWeb;

use strict;
use warnings;
use base qw/Class::Accessor::Fast/;

use NDWeb::Auth::User;

our $VERSION= "0.104";


BEGIN {
	#__PACKAGE__->mk_accessors(qw/config/);
}


sub setup {
	my $c = shift;

    $c->default_auth_store(
        Catalyst::Plugin::Authentication::Store::NDWeb->new(
        )
    );

    $c->NEXT::setup(@_);

}

sub new {
	my ( $class ) = @_;

	my $self = {
	};

	bless $self, $class;
}

sub from_session {
	my ( $self, $c, $frozenuser ) = @_;

	my $user = NDWeb::Auth::User->new();

	return $user->from_session($frozenuser, $c);
}

sub for_session {
	my ($self, $c, $user) = @_;
	return $user->for_session($c);
}

sub find_user {
	my ( $self, $authinfo, $c ) = @_;

	my $user = NDWeb::Auth::User->new();;

	return $user->load($authinfo, $c);
}

sub user_supports {
	my $self = shift;
	# this can work as a class method on the user class
	NDWeb::User->supports( @_ );
}

__PACKAGE__;

__END__

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut
