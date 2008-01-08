#**************************************************************************
#   Copyright (C) 2006 by Michael Andreen <harvATruinDOTnu>               *
#                                                                         *
#   This program is free software; you can redistribute it and/or modify  *
#   it under the terms of the GNU General Public License as published by  *
#   the Free Software Foundation; either version 2 of the License, or     *
#   (at your option) any later version.                                   *
#                                                                         *
#   This program is distributed in the hope that it will be useful,       *
#   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
#   GNU General Public License for more details.                          *
#                                                                         *
#   You should have received a copy of the GNU General Public License     *
#   along with this program; if not, write to the                         *
#   Free Software Foundation, Inc.,                                       *
#   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.         *
#**************************************************************************/

package NDWeb::Pages::Check;
use strict;
use warnings;
use ND::Include;
use CGI qw/:standard/;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{check} = __PACKAGE__;

sub parse {
	my $self = shift;
	if ($self->{URI} =~ m{^/.*/((\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?(?: |:(\d+))?)$}){
		param('coords',$1);
	}
}

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Check planets and galaxies';
	my $DBH = $self->{DBH};

	return $self->noAccess unless $self->{ATTACKER};

	$BODY->param(isBC => $self->isMember && ($self->isOfficer || $self->isBC));

	my ($x,$y,$z);
	if (param('coords') =~ /(\d+)(?: |:)(\d+)(?:(?: |:)(\d+))?(?: |:(\d+))?/){
		$x = $1;
		$y = $2;
		$z = $3;
		$BODY->param(Coords => "$x:$y".(defined $z ? ":$z" : ''));
	}else{
		$ND::ERROR .= p b q{Couldn't parse coords};
		return $BODY;
	}

	if ($self->isMember && defined param('cmd') && param('cmd') eq 'arbiter'){
		my $query = $DBH->prepare(q{SELECT count(*) AS friendlies FROM current_planet_stats WHERE x = ? AND y = ? 
			AND (planet_status IN ('Friendly','NAP') OR relationship IN ('Friendly','NAP'))});
		my ($count) = $DBH->selectrow_array($query,undef,$x,$y);
		if ($count > 0){
			$BODY->param(Arbiter => '<b>DO NOT ATTACK THIS GAL</b>');
		}else{
			$BODY->param(Arbiter => '<b>KILL THESE BASTARDS</b>');
		}
		log_message $ND::UID,"Arbiter check on $x:$y";
	}

	my $where = '';
	my $extra_columns = '';

	$where = 'AND z = ?' if defined $z;
	if ($self->isMember && $self->isOfficer){
		$extra_columns = ",planet_status,hit_us, alliance,relationship,nick";
	}elsif ($self->isMember && $self->isBC){
		$extra_columns = ", planet_status,hit_us, alliance,relationship";
	}

	my $query = $DBH->prepare(qq{Select p.id,coords(x,y,z), ((ruler || ' OF ') || p.planet) as planet,race,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day,
		p.value - p.size*200 - 
			COALESCE(ps.metal+ps.crystal+ps.eonium,0)/150 - 
			COALESCE(ss.total ,(SELECT COALESCE(avg(total),0) FROM structure_scans)::int)*1500 AS fleetvalue
		,(metal+crystal+eonium)/100 AS resvalue  $extra_columns 
		FROM current_planet_stats_full p 
			LEFT OUTER JOIN planet_scans ps ON p.id = ps.planet
			LEFT OUTER JOIN structure_scans ss ON p.id = ss.planet
		WHERE x = ? AND y = ? $where ORDER BY x,y,z ASC
	});

	if (defined $z){
		$query->execute($x,$y,$z);
	}else{
		$query->execute($x,$y);
		if ($self->isMember && ($self->isBC || $self->isOfficer) && !$self->isHC){
			log_message $ND::UID,"BC browsing $x:$y";
		}
	}
	my @planets;
	my $planet_id = undef;
	my $i = 0;
	while (my $planet = $query->fetchrow_hashref){
		$planet_id = $planet->{id};
		for my $type (qw/size score value xp/){
			$planet->{"${type}img"} = 'stay';
			$planet->{"${type}img"} = 'up' if $planet->{"${type}_gain_day"} > 0;
			$planet->{"${type}img"} = 'down' if $planet->{"${type}_gain_day"} < 0;
			$planet->{"${type}rankimg"} = 'stay';
			$planet->{"${type}rankimg"} = 'up' if $planet->{"${type}rank_gain_day"} < 0;
			$planet->{"${type}rankimg"} = 'down' if $planet->{"${type}rank_gain_day"} > 0;
			for my $type ($type,"${type}_gain","${type}_gain_day"){
				$planet->{$type} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
			}
		}
		if ($self->isMember && ($self->isOfficer || $self->isBC)){
			if ($z && defined $planet->{alliance} && $planet->{alliance} eq 'NewDawn' && not ($self->isHC || $self->isOfficer)){
				log_message $ND::UID,"BC browsing ND planet $planet->{coords} tick $self->{TICK}";
			}
		}
		$i++;
		$planet->{ODD} = $i % 2;
		delete $planet->{id};
		push @planets,$planet;
	}
	$BODY->param(GPlanets => \@planets);

	if ($z && $planet_id){
		$BODY->param(OnePlanet => 1);

		my $query = $DBH->prepare(q{ 
			SELECT i.id,i.mission, i.name, i.tick AS landingtick,MIN(eta) AS eta
				, i.amount, coords(x,y,z) AS target
			FROM fleets i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) t ON i.target = t.id
					AND t.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE  i.uid = -1
				AND i.sender = ?
				AND (i.tick > tick() - 14 OR i.mission = 'Full fleet')
			GROUP BY i.id,x,y,z,i.mission,i.tick,i.name,i.amount,i.ingal,i.uid
			ORDER BY i.tick,x,y,z
		});
		$query->execute($planet_id);
		my $ships = $DBH->prepare(q{SELECT ship,amount FROM fleet_ships WHERE id = ?});
		my @missions;
		$i = 0;
		while (my $mission = $query->fetchrow_hashref){
			$mission->{ODD} = $i++ % 2;
			$mission->{CLASS} = $mission->{mission};
			my @ships;
			$ships->execute($mission->{id});
			my $j = 0;
			while (my $ship = $ships->fetchrow_hashref){
				$ship->{ODD} = $j++ % 2;
				push @ships,$ship;
			}
			push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
			$mission->{ships} = \@ships;
			push @missions,$mission;
		}
		$BODY->param(Missions => \@missions);

		$query = $DBH->prepare(q{ 
			SELECT i.id,i.mission, i.name, i.tick AS landingtick,MIN(eta) AS eta
				, i.amount, coords(x,y,z) AS sender
			FROM fleets i
			LEFT OUTER JOIN (planets
				NATURAL JOIN planet_stats) s ON i.sender = s.id
					AND s.tick = ( SELECT MAX(tick) FROM planet_stats)
			WHERE  i.uid = -1
				AND i.target = ?
				AND (i.tick > tick() - 14 OR i.mission = 'Full fleet')
			GROUP BY i.id,x,y,z,i.mission,i.tick,i.name,i.amount,i.ingal,i.uid
			ORDER BY i.tick,x,y,z
		});
		$query->execute($planet_id);
		my @incomings;
		$i = 0;
		while (my $mission = $query->fetchrow_hashref){
			$mission->{ODD} = $i++ % 2;
			$mission->{CLASS} = $mission->{mission};
			my @ships;
			$ships->execute($mission->{id});
			my $j = 0;
			while (my $ship = $ships->fetchrow_hashref){
				$ship->{ODD} = $j++ % 2;
				push @ships,$ship;
			}
			push @ships, {ship => 'No', amount => 'ships'} if @ships == 0;
			$mission->{ships} = \@ships;
			push @incomings,$mission;
		}
		$BODY->param(Incomings => \@incomings);

		$query = $DBH->prepare(q{SELECT value,value_gain AS gain,tick FROM planet_stats 
			WHERE id = ? AND tick > tick() - 24});
		$query->execute($planet_id);
		my @values;
		while (my $value = $query->fetchrow_hashref){
			$value->{class} = 'Defend';
			$value->{class} = 'Attack' if $value->{gain} < 0;
			push @values, $value;
		}
		$BODY->param(Values => \@values);

		$query = $DBH->prepare(q{SELECT type,scan_id, tick FROM scans
			WHERE planet = ? AND tick > tick() - 168
			ORDER BY tick,type DESC
		});
		$query->execute($planet_id);
		my @scans;
		$i = 0;
		while (my $scan = $query->fetchrow_hashref){
			$scan->{ODD} = $i++ % 2;
			push @scans,$scan;
		}
		$BODY->param(Scans => \@scans);

		$query = $DBH->prepare(q{SELECT x,y,z,tick FROM planet_stats
			WHERE id = ? ORDER BY tick ASC});
		$query->execute($planet_id);
		my @coords;
		my $c = {x => 0, y => 0, z => 0};
		while (my $c2 = $query->fetchrow_hashref){
			if ($c->{x} != $c2->{x} || $c->{y} != $c2->{y} || $c->{z} != $c2->{z}){
				$c = $c2;
				push @coords,$c;
			}
		}
		$BODY->param(OldCoords => \@coords);

		$query = $DBH->prepare(q{SELECT DISTINCT ON(rid) tick,category,name,amount
			FROM planet_data pd JOIN planet_data_types pdt ON pd.rid = pdt.id
			WHERE pd.id = $1 ORDER BY rid,tick DESC
		});
		$query->execute($planet_id);
		my @pdata;
		$i = 0;
		while (my $data = $query->fetchrow_hashref){
			$data->{ODD} = ++$i % 2;
			$data->{amount} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
			push @pdata,$data;
		}
		$BODY->param(PlanetData => \@pdata);

	}
	$query = $DBH->prepare(q{SELECT x,y,
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
		AND x = $1 AND y = $2
		});
	$query->execute($x,$y) or $ND::ERROR .= p($DBH->errstr);

	my @galaxies;
	$i = 0;
	while (my $galaxy = $query->fetchrow_hashref){
		for my $type (qw/planets size score xp value/){
			#$galaxy->{$type} = prettyValue($galaxy->{$type});
			next unless defined $galaxy->{"${type}_gain_day"};
			$galaxy->{"${type}img"} = 'stay';
			$galaxy->{"${type}img"} = 'up' if $galaxy->{"${type}_gain_day"} > 0;
			$galaxy->{"${type}img"} = 'down' if $galaxy->{"${type}_gain_day"} < 0;
			unless( $type eq 'planets'){
				$galaxy->{"${type}rankimg"} = 'stay';
				$galaxy->{"${type}rankimg"} = 'up' if $galaxy->{"${type}rank_gain_day"} < 0;
				$galaxy->{"${type}rankimg"} = 'down' if $galaxy->{"${type}rank_gain_day"} > 0;
			}
			for my $type ($type,"${type}_gain","${type}_gain_day"){
				$galaxy->{$type} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
			}
		}
		$i++;
		$galaxy->{ODD} = $i % 2;
		push @galaxies,$galaxy;
	}
	$BODY->param(Galaxies => \@galaxies);

	return $BODY;
}

1;
