package NDWeb::Controller::Settings;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

use DateTime::TimeZone;

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
	my $dbh = $c->model;

	$c->stash(error => $c->flash->{error});

	my @stylesheets = ('Default');
	my $dir = $c->path_to('root/static/css/black.css')->dir;
	while (my $file = $dir->next){
		if(!$file->is_dir && $file->basename =~ m{^(\w+)\.css$}){
			push @stylesheets,$1;
		}
	}
	$c->stash(stylesheets => \@stylesheets);

	my ($birthday,$timezone) = $dbh->selectrow_array(q{
SELECT birthday,timezone FROM users WHERE uid = $1
		},undef,$c->user->id);
	$c->stash(birthday => $birthday);

	my @timezone = split m{/},$timezone,2;
	$c->stash(timezone => \@timezone);

	my @cat = DateTime::TimeZone->categories;
	unshift @cat, 'GMT';
	$c->stash(tzcategories => \@cat);

	my @countries = DateTime::TimeZone->names_in_category($timezone[0]);
	$c->stash(tzcountries => \@countries);
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

sub changeBirthday : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{UPDATE users SET birthday = NULLIF($2,'')::date
		WHERE uid = $1
		});
	eval{
		$query->execute($c->user->id,html_escape $c->req->param('birthday'));
	};
	if ($@){
		if ($@ =~ /invalid input syntax for type date/){
			$c->flash(error => 'Bad syntax for day, use YYYY-MM-DD.');
		}else{
			$c->flash(error => $@);
		}
	}
	$c->res->redirect($c->uri_for(''));
}

sub changeTimezone : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $timezone = $c->req->param('category');
	$timezone .= '/' . $c->req->param('country') if $c->req->param('country');
	my $query = $dbh->prepare(q{UPDATE users SET timezone = $2 WHERE uid = $1});
	eval{
		$dbh->selectrow_array(q{SELECT NOW() AT TIME ZONE $1},undef,$timezone);
		$query->execute($c->user->id,$timezone );
	};
	if ($@){
		$c->flash(error => $@);
	}
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
