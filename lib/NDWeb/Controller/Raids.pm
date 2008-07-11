package NDWeb::Controller::Raids;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use POSIX;
use NDWeb::Include;
use ND::Include;

=head1 NAME

NDWeb::Controller::Raids - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
	my ( $self, $c ) = @_;
	my $dbh = $c->model;

	my $launched = 0;
	my $query = $dbh->prepare(q{SELECT r.id,released_coords AS releasedcoords,tick,waves*COUNT(DISTINCT rt.id) AS waves,
			COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched,COUNT(NULLIF(rc.uid > 0,true)) AS blocked
		FROM raids r JOIN raid_targets rt ON r.id = rt.raid
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
		WHERE open AND not removed AND r.id 
			IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)
		GROUP BY r.id,released_coords,tick,waves});
	$query->execute($c->user->id);
	my @raids;
	while (my $raid = $query->fetchrow_hashref){
		$raid->{waves} -= $raid->{blocked};
		$raid->{claims} -= $raid->{blocked};
		delete $raid->{blocked};
		$launched += $raid->{launched};
		push @raids,$raid;
	}
	$c->stash(raids => \@raids);

	if ($c->check_user_roles(qw/raids_info/)){
		my $query = $dbh->prepare(q{SELECT r.id,open ,tick,waves*COUNT(DISTINCT rt.id) AS waves,
			COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched ,COUNT(NULLIF(uid > 0,true)) AS blocked
		FROM raids r JOIN raid_targets rt ON r.id = rt.raid
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
		WHERE not removed AND (not open 
			OR r.id NOT IN (SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?))
		GROUP BY r.id,open,tick,waves});
		$query->execute($c->user->id);
		my @raids;
		while (my $raid = $query->fetchrow_hashref){
			$raid->{waves} -= $raid->{blocked};
			$raid->{claims} -= $raid->{blocked};
			delete $raid->{blocked};
			$launched += $raid->{launched};
			push @raids,$raid;
		}
		$c->stash(closedraids => \@raids);


		$query = $dbh->prepare(q{SELECT r.id,tick,waves*COUNT(DISTINCT rt.id) AS waves,
			COUNT(rc.uid) AS claims, COUNT(nullif(rc.launched,false)) AS launched ,COUNT(NULLIF(uid > 0,true)) AS blocked
		FROM raids r JOIN raid_targets rt ON r.id = rt.raid
			LEFT OUTER JOIN raid_claims rc ON rt.id = rc.target
		WHERE removed
		GROUP BY r.id,tick,waves});
		$query->execute;
		my @oldraids;
		while (my $raid = $query->fetchrow_hashref){
			$raid->{waves} -= $raid->{blocked};
			$raid->{claims} -= $raid->{blocked};
			delete $raid->{blocked};
			$launched += $raid->{launched};
			push @oldraids,$raid;
		}
		$c->stash(removedraids => \@oldraids);
		$c->stash(launched => $launched);
	}

}

sub view : Local {
	my ( $self, $c, $raid ) = @_;
	my $dbh = $c->model;

	$c->forward('findRaid');
	$raid = $c->stash->{raid};


	$c->stash(raid => $raid->{id});
	my $noingal = '';
	my $planet;
	if ($c->user->planet){
		my $query = $dbh->prepare("SELECT value, score,x,y FROM current_planet_stats WHERE id = ?");
		$planet = $dbh->selectrow_hashref($query,undef,$c->user->planet);
		$noingal = "AND NOT (x = $planet->{x} AND y = $planet->{y})";
	}
	$c->stash(message => parseMarkup($raid->{message}));
	$c->stash(landingtick => $raid->{tick});
	my $targetquery = $dbh->prepare(qq{SELECT r.id, r.planet, size, score, value
		, p.x,p.y,p.z, race
		, p.value - p.size*200 - 
			COALESCE(ps.metal+ps.crystal+ps.eonium,0)/150 - 
			COALESCE(ss.total ,(SELECT
				COALESCE(avg(total),0) FROM
				structure_scans)::int)*1500 AS fleetvalue
		,(metal+crystal+eonium)/100 AS resvalue, comment
		, hidden, light, medium, heavy
		FROM current_planet_stats p 
		JOIN raid_targets r ON p.id = r.planet 
		LEFT OUTER JOIN planet_scans ps ON p.id = ps.planet
		LEFT OUTER JOIN structure_scans ss ON p.id = ss.planet
		WHERE r.raid = ?
		$noingal
		ORDER BY size});
	$targetquery->execute($raid->{id});
	my @targets;
	my %production = (0 => 'None', 35 => 'Light', 65 => 'Medium', 100 => 'High');
	while (my $target = $targetquery->fetchrow_hashref){
		my %target;
		if ($planet){
			if ($planet->{x} == $target->{x}){
				$target{style} = 'incluster';
			}
			$target{scorebash} = 'bash' if ($target->{score}/$planet->{score} < 0.4);
			$target{valuebash} = 'bash' if ($target->{value}/$planet->{value} < 0.4);
			#next if ($target->{score}/$planet->{score} < 0.4) && ($target->{value}/$planet->{value} < 0.4);
		}
		$target{id} = $target->{id};
		$target{race} = $target->{race};
		my $num = pow(10,length($target->{score})-2);
		$target{score} = "Hidden"; #ceil($target->{score}/$num)*$num;
		$num = pow(10,length($target->{value})-2);
		$target{value} = "Hidden"; #ceil($target->{value}/$num)*$num;
		$num = pow(10,length($target->{size})-2);
		$target{size} = floor($target->{size}/$num)*$num;
		$num = pow(10,length($target->{fleetvalue})-2);
		$target{fleetvalue} = floor($target->{fleetvalue}/$num)*$num;
		if (defined $target->{resvalue}){
			$num = pow(10,length($target->{resvalue})-2);
			$target{resvalue} = floor($target->{resvalue}/$num)*$num;
		}
		$target{comment} = parseMarkup($target->{comment}) if ($target->{comment});
		
		$target{hidden} = int($target->{hidden} / 100);
		$target{light} = $production{$target->{light}};
		$target{medium} = $production{$target->{medium}};
		$target{heavy} = $production{$target->{heavy}};

		my $unitscans = $dbh->prepare(q{ 
			SELECT DISTINCT ON (name) i.id,i.name, i.tick, i.amount 
			FROM fleets i
			WHERE  i.uid = -1
				AND i.sender = ?
				AND i.mission = 'Full fleet'
			GROUP BY i.id,i.tick,i.name,i.amount
			ORDER BY name,i.tick DESC
		});
		$unitscans->execute($target->{planet});
		my $ships = $dbh->prepare(q{SELECT ship,amount FROM fleet_ships
			WHERE id = ? ORDER BY num
		});
		my @missions;
		while (my $mission = $unitscans->fetchrow_hashref){
			my @ships;
			$ships->execute($mission->{id});
			while (my $ship = $ships->fetchrow_hashref){
				push @ships,$ship;
			}
			push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
			$mission->{ships} = \@ships;
			$mission->{amount} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
			delete $mission->{id};
			push @missions,$mission;
		}
		$target{missions} = \@missions;

		my $query = $dbh->prepare(q{SELECT DISTINCT ON(rid) tick,category,name,amount
			FROM planet_data pd JOIN planet_data_types pdt ON pd.rid = pdt.id
			WHERE pd.id = $1 AND rid in (1,2,3,4,5,6,9,10,14,15,16,17,18)
			ORDER BY rid,tick DESC
		});
		$query->execute($target->{planet});
		while (my $data = $query->fetchrow_hashref){
			$data->{amount} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
			$data->{name} =~ s/ /_/g;
			$target{$data->{category}.$data->{name}} = $data->{amount};
		}

		my @roids;
		my @claims;
		my $size = $target{size};
		for (my $i = 1; $i <= $raid->{waves}; $i++){
			my $roids = floor(0.25*$size);
			$size -= $roids;
			my $xp = 0;
			if ($planet){
				$xp = pa_xp($roids,$planet->{score},$planet->{value},$target->{score},$target->{value});
			}
			push @roids,{wave => $i, roids => $roids, xp => $xp};
			push @claims,{wave => $i}
		}
		$target{roids} = \@roids;
		$target{claims} = \@claims;

		push @targets,\%target;
	}
	@targets = sort {$b->{roids}[0]{xp} <=> $a->{roids}[0]{xp} or $b->{size} <=> $a->{size}} @targets;

	$c->stash(targets => \@targets);
}

sub log : Private {
	my ($self, $c, $raid, $message) = @_;
	my $dbh = $c->model;

	my $log = $dbh->prepare(q{INSERT INTO forum_posts (uid,ftid,message)
		VALUES($1,(SELECT ftid FROM raids WHERE id = $2),$3)
		});
	$log->execute($c->user->id,$raid,$message);
}

sub findRaid : Private {
	my ( $self, $c, $raid ) = @_;
	my $dbh = $c->model;

	my $query = $dbh->prepare(q{SELECT id,tick,waves,message,released_coords
		FROM raids WHERE id = ? AND open AND not removed AND id IN
			(SELECT raid FROM raid_access NATURAL JOIN groupmembers WHERE uid = ?)
		});
	$raid = $dbh->selectrow_hashref($query,undef,$raid,$c->user->id);
	$c->stash(raid => $raid);
}

=head1 AUTHOR

Michael Andreen (harv@ruin.nu)

=head1 LICENSE

GPL 2.0, or later.

=cut

1;
