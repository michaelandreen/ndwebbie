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

package NDWeb::Pages::Main;
use strict;
use warnings;
use CGI qw/:standard/;
use ND::Include;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{main} = 'NDWeb::Pages::Main';

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	$self->{TITLE} = 'Main Page';
	my $DBH = $self->{DBH};

	if (defined param('cmd')){
		if (param('cmd') eq 'fleet'){
			my $fleet = param('fleet');
			$fleet =~ s/,//g;
			my $amount = 0;
			my @ships;
			while ($fleet =~ m/((?:[A-Z][a-z]+ )*[A-Z][a-z]+)\s+(\d+)/g){
				$amount += $2;
				push @ships, [$1,$2];
			}
			if ($amount){
				$DBH->begin_work;
				eval{
					my $insert = $DBH->prepare(q{INSERT INTO fleets 
						(uid,sender,name,mission,tick,amount)
						VALUES (?,?,'Main','Full fleet',tick(),?) RETURNING id});
					my ($id) = $DBH->selectrow_array($insert,undef,$self->{UID}
						,$self->{PLANET},$amount) or die $DBH->errstr;
					$insert = $DBH->prepare('INSERT INTO fleet_ships 
						(id,ship,amount) VALUES (?,?,?)');
					for my $s (@ships){
						unshift @{$s},$id;
						$insert->execute(@{$s}) or die $DBH->errstr;
					}
				};
				if ($@){
					warn $@;
					$DBH->rollback;
				}else{
					$DBH->commit;
					$self->{RETURN} = 'REDIRECT';
					$self->{REDIR_LOCATION} = "/main";
					return;
				}
			}else{
				warn 'Fleet does not contain any ships';
			}
		}elsif (param('cmd') eq 'Recall Fleets'){
			$DBH->begin_work;
			my $updatefleets = $DBH->prepare('UPDATE fleets SET back = tick() + (tick() - (tick - eta))  WHERE uid = ? AND id = ?');

			for my $param (param()){
				if ($param =~ /^change:(\d+)$/){
					if($updatefleets->execute($ND::UID,$1)){
						log_message $ND::UID,"Member recalled fleet $1";
					}else{
						warn $DBH->errstr;
					}
				}
			}
			$DBH->commit or warn $DBH->errstr;
		}elsif (param('cmd') eq 'Change Fleets'){
			$DBH->begin_work;
			my $updatefleets = $DBH->prepare('UPDATE fleets SET back = ? WHERE uid = ? AND id = ?');
			for my $param (param()){
				if ($param =~ /^change:(\d+)$/){
					if($updatefleets->execute(param("back:$1"),$ND::UID,$1)){
						log_message $ND::UID,"Member set fleet $1 to be back tick: ".param("back:$1");
					}else{
						warn $DBH->errstr;
					}
				}
			}
			$DBH->commit or warn $DBH->errstr;
		}
	}
	if (param('sms')){
		my $query = $DBH->prepare('UPDATE users SET sms = ? WHERE uid = ?');
		$query->execute(escapeHTML(param('sms')),$ND::UID);
	}
	if (param('hostname')){
		my $query = $DBH->prepare('UPDATE users SET hostmask = ? WHERE uid = ?');
		$query->execute(escapeHTML(param('hostname')),$ND::UID);
	}
	if ($self->isMember() && !$self->{PLANET} && defined param('planet') && (param('planet') =~ m/(\d+)(?: |:)(\d+)(?: |:)(\d+)/)){
		my $query = $DBH->prepare(q{
			UPDATE users SET planet = 
			(SELECT id from current_planet_stats where x = ? AND y = ? AND z = ?)
			WHERE uid = ? });
		$query->execute($1,$2,$3,$ND::UID);
	}

	my ($motd) = $DBH->selectrow_array("SELECT value FROM misc WHERE id='MOTD'");

	$BODY->param(MOTD => parseMarkup($motd));
	$BODY->param(Username => $self->{USER});
	$BODY->param(isMember => $self->isMember());
	$BODY->param(isHC => $self->isHC());
	my @groups = map {name => $_}, sort keys %{$self->{GROUPS}};
	$BODY->param(Groups => \@groups);


	my $query = $DBH->prepare(q{SELECT planet,defense_points,attack_points,scan_points,humor_points, (attack_points+defense_points+scan_points/20) as total_points, sms,rank,hostmask FROM users WHERE uid = ?});

	my ($planet,$defense_points,$attack_points,$scan_points,$humor_points,$total_points,$sms,$rank,$hostname) = $DBH->selectrow_array($query,undef,$ND::UID);

	$self->{PLANET} = $planet unless $self->{PLANET};

	$BODY->param(NDRank => $rank);
	$BODY->param(DefensePoints => $defense_points);
	$BODY->param(AttackPoints => $attack_points);
	$BODY->param(ScanPoints => $scan_points);
	$BODY->param(HumorPoints => $humor_points);
	$BODY->param(TotalPoints => $total_points);

	$BODY->param(Planet => $planet);

	$query = $DBH->prepare(qq{
		SELECT c.id, c.landing_tick, dc.username,c.covered,
		TRIM('/' FROM concat(p2.race||' /')) AS race, TRIM('/' FROM concat(i.amount||' /')) AS amount,
		TRIM('/' FROM concat(i.eta||' /')) AS eta, TRIM('/' FROM concat(i.shiptype||' /')) AS shiptype,
		(c.landing_tick - tick()) AS curreta,
		TRIM('/' FROM concat(coords(p2.x,p2.y,p2.z) ||' /')) AS attackers
		FROM calls c 
		JOIN incomings i ON i.call = c.id
		JOIN current_planet_stats p2 ON i.sender = p2.id
		LEFT OUTER JOIN users dc ON c.dc = dc.uid
		WHERE c.member = ? AND (c.landing_tick - tick())  > 0
		GROUP BY c.id, c.landing_tick,dc.username,c.covered
		ORDER BY c.landing_tick DESC
		})or warn  $DBH->errstr;
	$query->execute($ND::UIN) or warn $DBH->errstr;

	my $i = 0;
	my @calls;
	while (my $call = $query->fetchrow_hashref){
		$call->{attackers} =~ s{(\d+:\d+:\d+)}{<a href="/check?coords=$1">$1</a>}g;
		unless(defined $call->{username}){
			$call->{dc} = 'Hostile';
			$call->{username} = 'none';
		}
		if($call->{covered}){
			$call->{covered} = 'Friendly';
		}else{
			$call->{covered} = 'Hostile';
		}
		$i++;
		$call->{ODD} = $i % 2;
		$call->{shiptype} = escapeHTML($call->{shiptype});
		push @calls, $call;
	}
	$BODY->param(Calls => \@calls);

	my $planetstats= $DBH->selectrow_hashref(q{SELECT x,y,z, ((ruler || ' OF ') || p.planet) as planet,race,
		size, size_gain, size_gain_day,
		score,score_gain,score_gain_day,
		value,value_gain,value_gain_day,
		xp,xp_gain,xp_gain_day,
		sizerank,sizerank_gain,sizerank_gain_day,
		scorerank,scorerank_gain,scorerank_gain_day,
		valuerank,valuerank_gain,valuerank_gain_day,
		xprank,xprank_gain,xprank_gain_day
		from current_planet_stats_full p
			WHERE id = ?},undef,$planet) if $planet;
	if ($planetstats){
		my $planet = $planetstats;
		for my $type (qw/size score value xp/){
			$planet->{$type} =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g; #Add comma for ever 3 digits, i.e. 1000 => 1,000
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
		$BODY->param(Planets => [$planet]);
		$BODY->param(PlanetCoords => "$planet->{x}:$planet->{y}:$planet->{z}");
	}


	$query = $DBH->prepare(q{SELECT f.id, coords(x,y,z) AS target, mission
		, f.amount, tick, back
FROM fleets f 
JOIN fleet_ships fs USING (id)
LEFT OUTER JOIN current_planet_stats p ON f.target = p.id
WHERE f.uid = ? AND f.sender = ? AND 
	(back >= ? OR (tick >= tick() -  24 AND name = 'Main'))
GROUP BY f.id, x,y,z, mission, tick,back,f.amount
ORDER BY x,y,z,mission,tick
		});

	my $ships = $DBH->prepare(q{SELECT ship,amount FROM fleet_ships where id = ?});

	$query->execute($self->{UID},$self->{PLANET},$self->{TICK}) or warn $DBH->errstr;
	my @fleets;
	$i = 0;
	while (my $fleet = $query->fetchrow_hashref){
		$fleet->{ODD} = $i % 2;
		my @ships;
		$ships->execute($fleet->{id});
		my $j = 0;
		while (my $ship = $ships->fetchrow_hashref){
			$ship->{ODD} = $i++ % 2;
			push @ships,$ship;
		}
		$fleet->{ships} = \@ships;
		push @fleets,$fleet;
	}
	$BODY->param(Fleets => \@fleets);

	$BODY->param(SMS => $sms);
	$BODY->param(Hostname => $hostname);
	return $BODY;
}


1;

