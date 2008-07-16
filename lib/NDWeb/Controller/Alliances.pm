package NDWeb::Controller::Alliances;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

NDWeb::Controller::Alliances - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched NDWeb::Controller::Alliances in Alliances.');
}

sub hostile : Local {
    my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	my $begintick = 0;
	my $endtick = $c->stash->{TICK};
	if ($c->req->param('ticks')){
		$begintick = $endtick - $c->req->param('ticks');
	}elsif(defined $c->req->param('begintick') && defined $c->req->param('endtick')){
		$begintick = $c->req->param('begintick');
		$endtick = $c->req->param('endtick');
	}

	my $query = $dbh->prepare(q{
		SELECT s.alliance_id AS id,s.alliance AS name,count(*) AS hostile_count
FROM calls c 
	JOIN incomings i ON i.call = c.id
	JOIN current_planet_stats s ON i.sender = s.id
WHERE c.landing_tick - i.eta > $1 and c.landing_tick - i.eta < $2
GROUP BY s.alliance_id,s.alliance
ORDER BY hostile_count DESC
		});
	$query->execute($begintick,$endtick);
	$c->stash(alliances => $query->fetchall_arrayref({}) );
	$c->stash(ticks => $endtick - $begintick);
	$c->stash(begin_tick => $begintick);
	$c->stash(end_tick => $endtick);
}

sub resources : Local {
    my ( $self, $c, $order ) = @_;
	my $dbh = $c->model;

	if (defined $order && $order =~ /^(size|score|resources|hidden|resplanet|hidplanet|nscore|nscore2|nscore3)$/){
		$order = "$1 DESC";
	}else{
		$order = "resplanet DESC";
	}

	my $query = $dbh->prepare(qq{
		SELECT a.id,a.name,a.relationship,s.members,s.score,s.size
		,r.resources,r.hidden,r.planets
		,(resources/planets)::bigint AS resplanet
		,(hidden/planets)::bigint AS hidplanet
		,((resources / 300) + (hidden / 100))::bigint AS scoregain
		,(score + (resources / 300) + (hidden / 100))::bigint AS nscore
		,((resources/planets*scoremem)/300 + (hidden/planets*scoremem)/100)::bigint AS scoregain2
		,(score + (resources/planets*scoremem)/300
			+ (hidden/planets*scoremem)/100)::bigint AS nscore2
		,((s.size::int8*(1400-tick())*250)/100 + score + (resources/planets*scoremem)/300
			+ (hidden/planets*scoremem)/100)::bigint AS nscore3
		,(s.size::int8*(1400-tick())*250)/100 AS scoregain3
		FROM (SELECT alliance_id AS id,sum(metal+crystal+eonium) AS resources, sum(hidden) AS hidden, count(*) AS planets 
		FROM planets p join planet_scans c ON p.id = c.planet GROUP by alliance_id) r 
			NATURAL JOIN alliances a 
			LEFT OUTER JOIN (SELECT *,LEAST(members,60) AS scoremem FROM alliance_stats
				WHERE tick = (SELECT max(tick) FROM alliance_stats)) s ON a.id = s.id
		ORDER BY $order
		});
	$query->execute;
	my @alliances;
	while (my $alliance = $query->fetchrow_hashref){
		push @alliances,$alliance;
	}
	$c->stash(alliances => \@alliances);
}


=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
