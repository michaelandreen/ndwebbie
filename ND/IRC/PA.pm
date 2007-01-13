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
package ND::IRC::PA;
use strict;
use warnings;
use ND::DB;
use ND::Include;
use ND::IRC::Access;
use ND::IRC::Misc;
use POSIX;
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/checkPlanet checkGal shipEff shipStop parseValue prettyValue/;

sub checkPlanet {
	my ($x,$y,$z,$intel) = @_;
	DB();
	my $f = $ND::DBH->prepare("SELECT ruler,planet,race,score,size,value,scorerank,sizerank,valuerank, xp, xprank, alliance FROM current_planet_stats WHERE x = ? AND y = ? and z = ?");
	$f->execute($x,$y,$z);
	while (my @row = $f->fetchrow()){
		@row = map (valuecolor(1),@row);
		my $ally = "";
		$ally = " Alliance=$row[11]," if $intel;
		$ND::server->command("notice $ND::target $x:$y:$z $row[0] OF $row[1],$ally Race=$row[2], Score=$row[3] ($row[6]), Size=$row[4] ($row[7]), Value=$row[5] ($row[8]), XP=$row[9] ($row[10])");
	}
}
sub checkGal {
	my ($x,$y) = @_;
	DB();
	my $f = $ND::DBH->prepare("SELECT name,score,size,value FROM galaxies WHERE x = ? AND y = ? and tick = (SELECT max(tick) from galaxies)");
	$f->execute($x,$y);
	while (my @row = $f->fetchrow()){
		@row = map (valuecolor(1),@row);
		$ND::server->command("notice $ND::target $x:$y $row[0], Score=$row[1], Size=$row[2], Value=$row[3]");
	}
}

sub shipEff {
	my ($amount,$ship,$value) = @_;
	$ship = "\%$ship\%";
	$amount = parseValue($amount);
	$value = parseValue($value);
	$value *= -1.5 if defined $value and $value < 0;

	my @ship = $ND::DBH->selectrow_array(q{
SELECT name,target,"type",damage,metal+crystal+eonium,init,"class",guns,race
FROM ship_stats WHERE name ILIKE ?
		}, undef, $ship);
	if (@ship){
		my $type = "kill";
		$type = "stun" if $ship[2] eq 'Emp';
		$type = "steal" if ($ship[2] eq 'Steal') or ($ship[2] eq 'Pod');

		$amount = int(($value*100/$ship[4])) if $amount eq 'value';
		$value = prettyValue(($amount*$ship[4]/100));
		my $text = "$amount $ship[0] ($ship[5]:$value) will $type:";
		my $st = $ND::DBH->prepare(q{
			SELECT name,"class","type",armor,metal+crystal+eonium,init,target,eres,race
			FROM ship_stats WHERE "class" = ?
			});
		$st->execute($ship[1]);
		while (my @target = $st->fetchrow()){
			my $dead = $ship[2] eq 'Emp' ? int($amount*$ship[7]*(100-$target[7])/100) : int($amount*$ship[3]/$target[3]);
			$value = prettyValue($dead*$target[4]/100);
			if (($target[6] eq $ship[6]) and ($target[5] <= $ship[5])){
				$target[5] = "${ND::C}04$target[5]$ND::C";
			}elsif(($target[6] eq $ship[6]) and ($target[5] > $ship[5])){
				$target[5] = "${ND::C}12$target[5]$ND::C";
			}
			$target[0] = "${ND::C}04$target[0]$ND::C" if $target[2] eq 'Norm' || $target[2] eq 'Cloak';
			$target[0] = "${ND::C}12$target[0]$ND::C" if $target[2] eq 'Emp';
			$target[0] = "${ND::C}13$target[0]$ND::C" if $target[2] eq 'Steal';
			$text .= " $ND::B$dead$ND::B $target[0] ($target[5]:$value),";
		}
		chop $text;
		$ND::server->command("notice $ND::target $text");
	}
	#print $text;
}

sub shipStop {
	my ($amount,$ship,$value) = @_;
	$ship = "\%$ship\%";
	$amount = parseValue($amount);
	$value = parseValue($value);
	$value *= -1.5 if defined $value and $value < 0;

	my @ship = $ND::DBH->selectrow_array(q{
SELECT name,target,"type",armor,metal+crystal+eonium,init,"class",eres,race
FROM ship_stats WHERE name ILIKE ?
		}, undef, $ship);
	if (@ship){
		$ship[0] = "${ND::C}04$ship[0]$ND::C" if $ship[2] eq 'Norm';
		$ship[0] = "${ND::C}12$ship[0]$ND::C" if $ship[2] eq 'Emp';
		$ship[0] = "${ND::C}13$ship[0]$ND::C" if $ship[2] eq 'Steal';

		$amount = int(($value*100/$ship[4])) if $amount eq 'value';
		$value = prettyValue(($amount*$ship[4]/100));
		my $text = "To stop $amount $ship[0] ($ship[5]:$value) you need:";
		my $st = $ND::DBH->prepare(q{
			SELECT name,"class","type",damage,metal+crystal+eonium,init,target,guns,race
			FROM ship_stats WHERE "target" = ?
			});
		$st->execute($ship[6]);
		while (my @stopper = $st->fetchrow()){
			my $needed = $stopper[2] eq 'Emp' ? ceil($amount*100/(100-$ship[7])/$stopper[7]) : ceil($amount*$ship[3]/$stopper[3]);
			$value = prettyValue($needed*$stopper[4]/100);
			if (($stopper[1] eq $ship[1]) and ($ship[5] <= $stopper[5])){
				$stopper[5] = "${ND::C}04$stopper[5]$ND::C";
			}elsif(($stopper[1] eq $ship[1]) and ($ship[5] > $stopper[5])){
				$stopper[5] = "${ND::C}12$stopper[5]$ND::C";
			}
			$stopper[0] = "${ND::C}04$stopper[0]$ND::C" if $stopper[2] eq 'Norm' || $stopper[2] eq 'Cloak';
			$stopper[0] = "${ND::C}12$stopper[0]$ND::C" if $stopper[2] eq 'Emp';
			$stopper[0] = "${ND::C}13$stopper[0]$ND::C" if $stopper[2] eq 'Steal';
			$text .= " $ND::B$needed$ND::B $stopper[0] ($stopper[5]:$value),";
		}
		chop $text;
		$ND::server->command("notice $ND::target $text");
	}
	#print $text;
}

sub calcXp {
	my ($x,$y,$z,$roids) = @_;

	my ($avalue,$ascore) = $ND::DBH->selectrow_array(q{
		SELECT value,score FROM current_planet_stats WHERE 
			id = (SELECT planet FROM users WHERE hostmask ILIKE ?);
		}, undef, $ND::address);
	my ($tvalue,$tscore) = $ND::DBH->selectrow_array(q{
		SELECT value,score FROM current_planet_stats WHERE 
			x = ? AND y = ? and z = ?;
		}, undef, $x,$y,$z);
	unless (defined $avalue && defined $ascore){
		$ND::server->command("notice $ND::target You don't have a planet specified");
		return;
	}
	unless (defined $tvalue && defined $tscore){
		$ND::server->command("notice $ND::target Doesn't seem to be a planet at $x:$y:$z");
		return;
	}
	my $xp = int(max($roids * 10 * (min(2,$tscore/$ascore) + min(2,$tvalue/$avalue) - 1),0));
	my $score = 60 * $xp;
	$ND::server->command("notice $ND::target You will gain $ND::B$xp$ND::B XP, $ND::B$score$ND::B score, if you steal $roids roids from $x:$y:$z");
}

1;
