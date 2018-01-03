package NDWeb::Controller::Settings;

use strict;
use warnings;
use feature ":5.10";
use parent 'Catalyst::Controller';

use NDWeb::Include;

use DateTime::TimeZone;
use Mail::Sendmail;
use Email::Valid;

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

	my ($birthday,$timezone,$email) = $dbh->selectrow_array(q{
SELECT birthday,timezone,email FROM users WHERE uid = $1
		},undef,$c->user->id);
	$c->stash(birthday => $birthday);
	$c->stash(email =>  $c->flash->{email} // $email);

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

	my $timezone = $c->req->param('timezone');
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

	if (length $c->req->param('pass') < 4) {
		$c->flash(error => "Your password need to be at least 4 characters");
	} else {
		my $query = $dbh->prepare(q{UPDATE users SET password = $1
			WHERE password = crypt($2,password) AND uid = $3
		});
		$query->execute($c->req->param('pass'),$c->req->param('oldpass'),$c->user->id);

		$c->flash(error => "Old password was invalid") unless $query->rows;
	}

	$c->res->redirect($c->uri_for(''));
}

sub changeEmail : Local {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $email = $c->req->param('email');

	unless (Email::Valid->address($email)){
		$c->flash(email => $email);
		$c->flash(error => 'Invalid email address');
		$c->res->redirect($c->uri_for(''));
		return,
	}

	eval{
		my $insert = $dbh->prepare(q{
INSERT INTO email_change (uid,email) VALUES ($1,$2) RETURNING id;
			});
		$insert->execute($c->user->id,$email);

		my ($id) = $insert->fetchrow_array;

		my %mail = (
			smtp => 'localhost',
			To      => $email,
			From    => 'NewDawn Command <nd@ruin.nu>',
			'Content-type' => 'text/plain; charset="UTF-8"',
			Subject => 'Change email address',
			Message => qq{
You have requested to change email address on the NewDawn website.
If that is not the case, then feel free to ignore this email. Otherwise
use the following url to confirm the change:

}.$c->uri_for('confirmEmail',$id)."\n",
		);

		if (sendmail %mail) {
			$c->flash(error => 'Sent mail for confirmation.');
		}else {
			$c->flash(error => $Mail::Sendmail::error);
		}
	};
	if($@){
		if($@ =~ /duplicate key value violates unique constraint/){
			$c->flash(email => $email);
			$c->flash(error => 'Something went wrong, try to set the email again');
		}else{
			die $@;
		}
	}
	$c->res->redirect($c->uri_for(''));
}

sub confirmEmail : Local {
	my ( $self, $c, $id ) = @_;
	my $dbh = $c->model;

	$dbh->begin_work;
	my $query = $dbh->prepare(q{
UPDATE email_change SET confirmed = TRUE
WHERE uid = $1 AND id = $2 AND NOT confirmed
RETURNING email
		});
	$query->execute($c->user->id,$id);
	my ($email) = $query->fetchrow_array;

	if ($email){
		$dbh->do(q{UPDATE users SET email = $2 WHERE uid = $1}
			,undef,$c->user->id,$email);
		$c->flash(error => "Email updated.");
	}else{
		$c->flash(error => "$id is not a valid change id for your account, or already confirmed");
	}
	$dbh->commit;
	$c->res->redirect($c->uri_for(''));
}


=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
