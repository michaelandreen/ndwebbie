package NDWeb::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use ND::Include;
use Geo::IP;


#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

NDWeb::Controller::Root - Root Controller for NDWeb

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub index : Local Path Args(0) {
	my ( $self, $c ) = @_;

	$c->visit('/wiki/index');
}

sub default : Path {
	my ( $self, $c ) = @_;
	$c->stash(template => 'default.tt2');
	$c->response->status(410);
}

sub login : Local {
	my ($self, $c) = @_;

	if ($c->login){
		my $gi = Geo::IP->new(GEOIP_STANDARD);
		my $country = $gi->country_code_by_addr($c->req->address) || '??';

		my $remember = 0;
		if ($c->req->param('remember')){
			$c->session_time_to_live( 604800 ); # expire in one week.
			$remember = 1;
		}
		my $log = $c->model->prepare(q{INSERT INTO session_log
			(uid,time,ip,country,session,remember)
			VALUES ($1,NOW(),$2,$3,$4,$5)
		});
		$log->execute($c->user->id,$c->req->address
			,$country,$c->sessionid,$remember);

		$c->forward('redirect');
		return;
	} elsif ($c->req->method eq 'POST'){
		$c->res->status(400);
	}
}

sub logout : Local {
	my ($self, $c) = @_;
	$c->logout;
	$c->delete_session("logout");
	$c->res->redirect($c->uri_for('index'));
}

my %clickatellstatus = (
	"001", "Message unknown. The delivering network did not recognise the message type or content.",
	"002", "Message queued. The message could not be delivered and has been queued for attempted redelivery.",
	"003", "Delivered. Delivered to the network or gateway (delivered to the recipient).",
	"004", "Received by recipient. Confirmation of receipt on the handset of the recipient.",
	"005", "Error with message. There was an error with the message, probably caused by the content of the message itself.",
	"006", "User cancelled message delivery. Client cancelled the message by setting the validity period, or the message was terminated by an internal mechanism.",
	"007", "Error delivering message An error occurred delivering the message to the handset.",
	"008", " OK. Message received by gateway.",
	"009", "Routing error. The routing gateway or network has had an error routing the message.",
	"010", "Message expired. Message has expired at the network due to the handset being off, or out of reach.",
	"011", "Message queued for later delivery. Message has been queued at the Clickatell gateway for delivery at a later time (delayed delivery).",
	"012", "Out of credit. The message cannot be delivered due to a lack of funds in your account. Please re-purchase credits."
);


sub smsconfirm : Local {
	my ($self, $c) = @_;
	my $dbh = $c->model;

	my $sms = $dbh->prepare(q{
UPDATE sms SET status = $2, cost = $3
	,time = TIMESTAMP WITH TIME ZONE 'epoch' + $4 * INTERVAL '1 second'
WHERE msgid = $1
		});

	$sms->execute($c->req->param('apiMsgId')
		,$clickatellstatus{$c->req->param('status')}
		,$c->req->param('charge')
		,$c->req->param('timestamp'));

	$c->stash(template => 'default.tt2');
}


sub begin : Private {
	my ($self, $c) = @_;

	 $c->res->header( 'Cache-Control' =>
		'no-store, no-cache, must-revalidate,'.
		'post-check=0, pre-check=0, max-age=0'
	);
	$c->res->header( 'Pragma' => 'no-cache' );
	$c->res->header( 'Expires' => 'Thu, 01 Jan 1970 00:00:00 GMT' );
}

sub listTargets : Private {
	my ($self, $c) = @_;

	my $dbh = $c ->model;

	my $query = $dbh->prepare(q{SELECT t.id, r.id AS raid, r.tick+c.wave-1 AS landingtick, 
		(released_coords AND old_claim(timestamp)) AS released_coords, coords(x,y,z),c.launched,c.wave,c.joinable
FROM raid_claims c
	JOIN raid_targets t ON c.target = t.id
	JOIN raids r ON t.raid = r.id
	JOIN current_planet_stats p ON t.planet = p.id
WHERE c.uid = $1 AND r.tick+c.wave > tick() AND r.open AND not r.removed
ORDER BY r.tick+c.wave,x,y,z});
	$query->execute($c->user->id) or die $dbh->errstr;
	my @targets;
	while (my $target = $query->fetchrow_hashref){
		push @targets, $target;
	}

	$c->stash(claimedtargets => \@targets);
}

sub listAlliances : Private {
	my ($self, $c) = @_;
	my @alliances;
	push @alliances,{id => -1, name => ''};
	my $query = $c->model->prepare(q{SELECT id,name FROM alliances ORDER BY LOWER(name)});
	$query->execute;
	while (my $ally = $query->fetchrow_hashref){
		push @alliances,$ally;
	}
	$c->stash(alliances => \@alliances);
}

sub sslurl {
	return $_[0];
}

sub auto : Private {
	my ($self, $c) = @_;
	my $dbh = $c ->model;

	$c->stash(dbh => $dbh);

	$c->stash(sslurl => \&sslurl);

	$dbh->do(q{SET timezone = 'GMT'});

	$c->stash(TICK =>$dbh->selectrow_array('SELECT tick()',undef));
	$c->stash(STICK =>$dbh->selectrow_array('SELECT max(tick) FROM planet_stats',undef));
	$c->stash->{game}->{tick} = $c->stash->{TICK};

	if ($c->user_exists){
		$c->stash(UID => $c->user->id);
	}else{
		$c->stash(UID => -4);
	}
}

sub redirect : Private {
	my ($self, $c) = @_;
	$c->res->redirect($c->uri_for('/'.$c->session->{referrer}));
}

sub access_denied : Private {
	my ($self, $c, $action) = @_;

	$c->stash->{template} = 'access_denied.tt2';
	$c->res->status(403);

}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {
	my ($self, $c) = @_;

	if ($c->res->status >= 300 && $c->res->status <= 400 ){
		return;
	}

	my $dbh = $c ->model;

	if (scalar @{ $c->error } ){
		if ($c->error->[0] =~ m/Can't call method "id" on an undefined value at/){
			$c->stash->{template} = 'access_denied.tt2';
			$c->res->status(403);
			$c->clear_errors;
		}elsif ($c->error->[0] =~ m/Missing roles: /){
			$c->stash->{template} = 'access_denied.tt2';
			$c->res->status(403);
			$c->clear_errors;
		}
	}

	if ($c->user_exists){
		my $fleetupdate = 0;
		if ($c->check_user_roles(qw/member_menu/)){
			$fleetupdate = $dbh->selectrow_array(q{
SELECT tick FROM fleets WHERE planet = ? AND tick > tick() - 24
AND mission = 'Full fleet' AND name IN ('Main','Advanced Unit');
				},undef,$c->user->planet);
			$fleetupdate = 0 unless defined $fleetupdate;
		}

		my ($unread,$newposts) = $dbh->selectrow_array(q{SELECT * FROM unread_posts($1)}
			,undef,$c->user->id);

		$c->stash(user => {
			id => $c->user->id,
			name => $c->user->username,
			css => $c->user->css,
			newposts => $newposts,
			unreadposts => $unread
		});
		$c->stash->{user}->{attacker} = $c->check_user_roles(qw/attack_menu/)
			&& (!$c->check_user_roles(qw/member_menu/)
				|| ($c->user->planet && (($c->stash->{TICK} - $fleetupdate < 24)
					|| $c->check_user_roles(qw/no_fleet_update/)))),
		$c->forward('listTargets');
	}
	my $birthdays = $dbh->prepare(q{SELECT username
			,date_part('year',age(birthday)) AS age
			FROM users WHERE birthday IS NOT NULL
				AND mmdd(birthday) = mmdd(CURRENT_DATE)
		});
	$birthdays->execute;
	$c->stash(birthdays => $birthdays->fetchall_arrayref({}));

	if ($c->res->status == 200 || $c->req->method eq 'GET'){
		$c->session->{referrer} = $c->req->path;
	}
}

=head1 AUTHOR

Michael Andreen	(harv@ruin.nu)

=head1 LICENSE

GPL 2, or later.

=cut

1;
