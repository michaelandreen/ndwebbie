package NDWeb::Controller::Rankings;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use NDWeb::Include;

=head1 NAME

NDWeb::Controller::Rankings - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

#sub index :Path :Args(0) {
#    my ( $self, $c ) = @_;
#
#    $c->response->body('Matched NDWeb::Controller::Rankings in Rankings.');
#}

sub planets : Local {
	my ( $self, $c, $order, $offset ) = @_;
	my $dbh = $c->model;

	my $error = '';

	$offset = 0 unless $offset;
	$c->detach('/default') if $offset < 0;
	$c->stash(offset => $offset);

	$c->stash( comma => \&comma_value);

	if (defined $order && $order =~ /^(scorerank|sizerank|valuerank|xprank|hit_us)$/){
		$order = $1;
	}else {
		$order = 'scorerank';
	}
	my $browse = qq{ORDER BY $order DESC LIMIT 100 OFFSET ?};
	if ($order =~ /rank$/){
		$browse = qq{WHERE $order > ? ORDER BY $order ASC LIMIT 100};
	}
	$c->stash(order => $order);

	my $extra_columns = '';
	if ($c->check_user_roles(qw/rankings_planet_intel/)){
		$c->stash(extracolumns => 1);
		$extra_columns = ",planet_status,hit_us, alliance,relationship,nick";
	}

	my $query = $dbh->prepare(qq{SELECT id,x,y,z,ruler,planet,race,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day
		$extra_columns FROM current_planet_stats_full
		$browse
		});
	$query->execute($offset);
	my @planets;
	while (my $planet = $query->fetchrow_hashref){
		push @planets,$planet;
	}
	$c->detach('/default') unless @planets;
	$c->stash(planets => \@planets);
}

sub galaxies : Local {
	my ( $self, $c, $order, $offset ) = @_;
	my $dbh = $c->model;

	my $error = '';

	$offset = 0 unless $offset;
	$c->detach('/default') if $offset < 0;
	$c->stash(offset => $offset);

	$c->stash( comma => \&comma_value);

	if (defined $order && $order =~ /^(scorerank|sizerank|valuerank|xprank|planets)$/){
		$order = $1;
	}else{
		$order = 'scorerank';
	}
	$c->stash(order => $order);

	my $browse = qq{ORDER BY $order DESC LIMIT 100 OFFSET ?};
	if ($order =~ /rank$/){
		$browse = qq{AND $order > ? ORDER BY $order ASC LIMIT 100};
	}
	my $query = $dbh->prepare(qq{SELECT x,y,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day,
		planets,planets_gain,planets_gain_day
		FROM galaxies g 
		WHERE tick = ( SELECT max(tick) AS max FROM galaxies)
		$browse
		});
	$query->execute($offset);
	my @galaxies;
	while (my $galaxy = $query->fetchrow_hashref){
		push @galaxies,$galaxy;
	}
	$c->detach('/default') unless @galaxies;
	$c->stash(galaxies => \@galaxies);
}


sub alliances : Local {
	my ( $self, $c, $order, $offset ) = @_;
	my $dbh = $c->model;

	my $error = '';

	$offset = 0 unless $offset;
	$c->detach('/default') if $offset < 0;
	$c->stash(offset => $offset);

	$c->stash( comma => \&comma_value);

	if (defined $order && $order =~ /^(scorerank|sizerank|valuerank|xprank|avgsize|avgscore|members)$/){
		$order = $1;
	}else{
		$order = 'scorerank';
	}
	$c->stash(order => $order);

	my $browse = qq{ORDER BY $order DESC LIMIT 100 OFFSET ?};
	if ($order =~ /rank$/){
		$browse = qq{WHERE $order > ? ORDER BY $order ASC LIMIT 100};
	}
	my $query = $dbh->prepare(qq{SELECT a.name,a.id,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		avgsize,avgsize_gain,avgsize_gain_day,
		avgscore,avgscore_gain,avgscore_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		members,members_gain,members_gain_day
	FROM ( SELECT *, (size/members) AS avgsize
			,(score/scoremem) AS avgscore
			,(size_gain/members) AS avgsize_gain
			,(score_gain/scoremem) AS avgscore_gain
			,(size_gain_day/members) AS avgsize_gain_day
			,(score_gain_day/scoremem) AS avgscore_gain_day
			FROM (SELECT *,(CASE WHEN members > 60 THEN 60 ELSE members END) AS scoremem
				FROM alliance_stats WHERE
					tick = ( SELECT max(tick) AS max FROM alliance_stats)) ast2
		) ast
		NATURAL JOIN alliances a
		$browse
		});
	$query->execute($offset);
	my @alliances;
	while (my $alliance = $query->fetchrow_hashref){
		push @alliances,$alliance;
	}
	$c->detach('/default') unless @alliances;
	$c->stash(alliances => \@alliances);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later

=cut

1;
