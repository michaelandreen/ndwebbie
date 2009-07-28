package NDWeb::Controller::Graphs;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use ND::Include;

=head1 NAME

NDWeb::Controller::Graphs - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub begin : Private {
	my ( $self, $c ) = @_;

	$c->stash(width => 500);
	$c->stash(height => 300);
	$c->stash(settings => {
		line_width => 1,
		y_number_format => sub { prettyValue abs $_[0]},
		legend_placement => 'BL',
		#zero_axis => 1,
		box_axis => 0,
		boxclr => 'black',
		axislabelclr => 'black',
		use_axis => [2,1,2,2],
		y1_label => 'size',
		two_axes => 1,
		y2_label => 'rest',
		});
	$c->stash(defaultgraph => 1);
}

sub planetranks : Local {
	my ( $self, $c, $planet ) = @_;
	my $dbh = $c->model;

	$c->cache_page(3600);

	$c->stash->{settings}->{y_max_value} = '0';
	my $query = $dbh->prepare(q{SELECT tick,-scorerank AS score,-sizerank AS size
		,-valuerank AS value,-xprank AS xp
		FROM planets NATUral JOIN planet_stats
		WHERE pid = $1 ORDER BY tick ASC
		});
	$query->execute($planet);
	$c->stash(query => $query);
}

sub planetstats : Local {
	my ( $self, $c, $planet ) = @_;
	my $dbh = $c->model;

	$c->cache_page(3600);

	$c->stash->{settings}->{y_min_value} = '0';
	my $query = $dbh->prepare(q{SELECT tick,score,size,value,xp*60 AS "xp*60"
		FROM planets NATURAL JOIN planet_stats
		WHERE pid = $1 ORDER BY tick ASC
		});
	$query->execute($planet);
	$c->stash(query => $query);
}


sub galaxyranks : Local {
	my ( $self, $c, $x,$y ) = @_;
	my $dbh = $c->model;

	$c->cache_page(3600);

	$c->stash->{settings}->{title} = "Ranks : $x:$y";
	$c->stash->{settings}->{y_max_value} = '0';
	my $query = $dbh->prepare(q{SELECT tick,-scorerank AS score,-sizerank AS size
		,-valuerank AS value,-xprank AS xp
		FROM galaxies WHERE x = $1 AND y = $2
		ORDER BY tick ASC
		});
	$query->execute($x,$y);
	$c->stash(query => $query);
}

sub galaxystats : Local {
	my ( $self, $c, $x,$y ) = @_;
	my $dbh = $c->model;

	$c->cache_page(3600);

	$c->stash->{settings}->{title} = "Stats : $x:$y";
	$c->stash->{settings}->{y_min_value} = '0';
	my $query = $dbh->prepare(q{SELECT tick,score,size,value,xp*60 AS "xp*60"
		FROM galaxies WHERE x = $1 AND y = $2
		ORDER BY tick ASC
		});
	$query->execute($x,$y);
	$c->stash(query => $query);
}

sub planetvsnd : Local {
	my ( $self, $c, $planet ) = @_;
	my $dbh = $c->model;

	$c->cache_page(3600);

	$c->stash->{settings}->{title} = 'You vs ND AVG';
	$c->stash->{settings}->{use_axis} = [2,1,1,2];
	$c->stash->{settings}->{y2_label} = 'score';

	my $query = $dbh->prepare(q{SELECT a.tick,a.score/LEAST(members,60) AS NDscore
		,a.size/members as NDsize,memsize, memscore
		FROM (SELECT tick,size AS memsize,score AS memscore
			FROM planets p JOIN planet_stats ps USING (pid) WHERE pid = $1) p
		JOIN alliance_stats a ON a.tick = p.tick
		WHERE aid = 1 ORDER BY tick
		});
	$query->execute($planet);
	$c->stash(query => $query);
}


sub alliancevsintel : Local {
	my ( $self, $c, $alliance ) = @_;
	my $dbh = $c->model;

	$c->stash->{settings}->{title} = 'Alliance vs known members';
	$c->stash->{settings}->{use_axis} = [2,1,1,2];
	$c->stash->{settings}->{y2_label} = 'score';

	my $query = $dbh->prepare(q{SELECT a.tick,a.score,a.size,memsize, memscore
		FROM (SELECT tick,aid,SUM(size) AS memsize,SUM(score) AS memscore
			FROM alliances a
				JOIN planets p USING (alliance)
				JOIN planet_stats ps USING (pid)
			GROUP BY tick,aid ) p
			JOIN alliance_stats a USING (aid,tick)
		WHERE aid = $1
			AND tick > (SELECT max(tick) - 50 FROM alliance_stats)
		ORDER BY tick
		});
	$query->execute($alliance);
	$c->stash(query => $query);
}

sub avgalliancevsintel : Local {
	my ( $self, $c, $alliance ) = @_;
	my $dbh = $c->model;

	$c->stash->{settings}->{title} = 'Average alliance vs known members';
	$c->stash->{settings}->{use_axis} = [2,1,1,2];
	$c->stash->{settings}->{y2_label} = 'score';

	my $query = $dbh->prepare(q{SELECT a.tick,a.score/LEAST(members,60) AS score
		,a.size/members AS size,memsize, memscore
		FROM (SELECT tick,aid,AVG(size) AS memsize,AVG(score) AS memscore
			FROM alliances a
				JOIN planets p USING (alliance)
				JOIN planet_stats ps USING (pid)
			GROUP BY tick,aid) p
		JOIN alliance_stats a USING (aid,tick)
		WHERE aid = $1
			AND tick > (SELECT max(tick) - 50 FROM alliance_stats)
		ORDER BY tick
		});
	$query->execute($alliance);
	$c->stash(query => $query);
}


sub end : ActionClass('RenderView') {
	my ( $self, $c ) = @_;
	$c->res->headers->content_type('image/png');
	if ($c->stash->{defaultgraph}){
		$c->stash(template => 'graphs/index.tt2');

		my $query = $c->stash->{query};
		my $fields = $query->{NUM_OF_FIELDS};
		my @fields;
		for (my $i = 0; $i < $fields; $i++){
			push @fields,[];
		}
		while (my @result = $query->fetchrow){
			for (my $i = 0; $i < $fields; $i++){
				push @{$fields[$i]},$result[$i];
			}
		}
		$c->stash->{settings}->{x_label_skip} = int(1+(scalar @{$fields[0]}) / 6);
		my @legend = @{$query->{NAME}}[1..$fields];
		$c->stash(legend => \@legend);
		$c->stash(data => \@fields);
	}
	
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
