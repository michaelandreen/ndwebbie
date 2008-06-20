package NDWeb::Controller::Settings;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Settings - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
		
	my @stylesheets = ('Default');
	my $dir = $c->path_to('root/static/css/black.css')->dir;
	while (my $file = $dir->next){
		if(!$file->is_dir && $file->basename =~ m{^(\w+)\.css$}){
			push @stylesheets,$1;
		}
	}
	$c->stash(stylesheets => \@stylesheets);

}

sub changeStylesheet : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{UPDATE users SET css = NULLIF($2,'Default')
		WHERE uid = $1
	});
	$query->execute($c->user->id,html_escape $c->req->param('stylesheet'));

	$c->res->redirect($c->uri_for(''));
}


sub changePassword : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{UPDATE users SET password = MD5($1)
		WHERE password = MD5($2) AND uid = $3
		});
	$query->execute($c->req->param('pass'),$c->req->param('oldpass'),$c->user->id);

	$c->res->redirect($c->uri_for(''));
}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
