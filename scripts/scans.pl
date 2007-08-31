#!/usr/bin/perl
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


use strict;
use warnings;
use CGI;
use DBI;
use DBD::Pg qw(:pg_types);
use LWP::Simple;

our $dbh;
for my $file ("/home/whale/db.pl")
{
	unless (my $return = do $file){
		warn "couldn't parse $file: $@" if $@;
		warn "couldn't do $file: $!"    unless defined $return;
		warn "couldn't run $file"       unless $return;
	}
}

$dbh->trace("3","/tmp/scanstest");
$dbh->do("SET CLIENT_ENCODING TO 'LATIN1';");

my $scangroups = $dbh->prepare(q{SELECT scan_id,tick,scan FROM scans WHERE "type" = 'group' AND scan ~ '^-?[0-9]+$'});
my $oldscan = $dbh->prepare(q{SELECT scan_id FROM scans WHERE scan_id = ? AND tick >= tick() - 168});
my $addScan = $dbh->prepare(q{INSERT INTO scans (scan_id,tick,"type") VALUES (?,?,COALESCE(?,'-1'))});
my $donegroup = $dbh->prepare(q{UPDATE scans SET "type" = 'donegroup' WHERE scan_id = ? AND "type" = 'group' AND tick = ?});

$scangroups->execute;

while (my @group = $scangroups->fetchrow){
	my $file = get("http://game.planetarion.com/showscan.pl?scan_grp=$group[0]");

	my $points = 0;
	while ($file =~ m/showscan.pl\?scan_id=(\d+)/g){
		unless ($dbh->selectrow_array($oldscan,undef,$1)){
			$addScan->execute($1,$group[1],$group[2]);
			++$points;
		}
	}
	my $f = $dbh->prepare('UPDATE users SET scan_points = scan_points + ? WHERE uid = ? ');
	$f->execute($points,$group[2]);
	$donegroup->execute($group[0],$group[1]);
}

my $emptyscans = $dbh->prepare('SELECT scan_id,tick,"type"::integer,tick() FROM scans WHERE planet is NULL AND type ~ \'^-?[0-9]+$\'');
my $update = $dbh->prepare('UPDATE scans SET tick = ?, "type" = ?, scan = ? , planet = ? WHERE scan_id = ? AND tick = ?');
$addScan = $dbh->prepare('INSERT INTO scans (tick,scan_id,"type",scan,planet) VALUES($1,$2,$3,$4,$5)') or die $dbh->errstr;
my $findplanet = $dbh->prepare('SELECT planetid(?,?,?,?)');
my $delscan = $dbh->prepare('DELETE FROM scans WHERE scan_id = ? AND tick = ?');
unless ($emptyscans->execute){
	my $cleanup = $dbh->prepare('UPDATE scans SET "type" = \'-1\' WHERE planet is NULL');
	$cleanup->execute;
	$emptyscans->execute;
}
while (my @scan = $emptyscans->fetchrow){
	my $file = get("http://game.planetarion.com/showscan.pl?scan_id=$scan[0]");
	if ($file =~ /((?:\w| )*) (?:Scan|Probe) on (\d+):(\d+):(\d+) in tick (\d+)/){
		my $type = $1;
		my $x = $2;
		my $y = $3;
		my $z = $4;
		my $tick = $5;
		my ($planet) = $dbh->selectrow_array($findplanet,undef,$x,$y,$z,$tick);
		unless ($planet){
			if ($scan[1] + 48 < $scan[3]){
				$delscan->execute($scan[0],$scan[1]);
			}
			next;
		}
		my $scantext = "";
		if ($file =~ /(Note: [^<]*)/){
			$scantext .= qq{
			<table class="closedPlanet">
			<tr><td>$1</td></tr>
			</table>};
		}
		if ($type eq 'Planet'){
			$file =~ s/(\d),(\d)/$1$2/g;
			if($file =~ m/Metal\D+(\d+)\D+(\d+).+?Crystal\D+(\d+)\D+(\d+).+?Eonium\D+(\d+)\D+(\d+)/s){
				$scantext .= <<HTML
	<table cellpadding="2">
	<tr><th></th><th>Metal</th><th>Crystal</th><th>Eonium</th></tr>
	<tr><td>Asteroids</td><td>$1</td><td>$3</td><td>$5</td></tr>
	<tr><td>Resources</td><td>$2</td><td>$4</td><td>$6</td></tr>
	</table>
HTML
				}
			;
			my $f = $dbh->prepare("UPDATE covop_targets SET metal = ?, crystal = ?, eonium = ? WHERE planet = ?");
			if ($f->execute($2,$4,$6,$planet) < 1){
				$f = $dbh->prepare("INSERT INTO covop_targets (planet,metal, crystal, eonium) VALUES(?,?,?,?)");
				$f->execute($planet,$4,$5,$6);
			}
		}elsif ($type eq 'Jumpgate'){
			$scantext .= <<HTML
	<table>
	<tr>
	<th>Coords</th>
	<th>Mission</th>
	<th>Fleet</th>
	<th>Eta</th>
	<th>Amount</th>
	</tr>
HTML
			;
			my $f = $dbh->prepare("SELECT add_intel(?,?,?,?,?,?,?,?,?,?,-1)");
			my $i = 1;
			while ($file =~ m/(\d+):(\d+):(\d+)\D+"left"\>(Attack|Defend|Return)<\/td><td>([^<]*)<\/td><td>(\d+)\D+(\d+)/g){
				my $row = "odd";
				$row = "even" if ($i % 2 == 0);
				if ($4 ne 'Return'){
					$f->execute($tick,$6,$x,$y,$z,$1,$2,$3,$7,$4);# or $server->command("echo " . DBI->errstr);
				}
				$scantext .= qq{
	<tr class="$row"><td><a href="check?coords=$1:$2:$3">$1:$2:$3</a></td><td class="$4">$4</td><td>$5</td><td>$6</td><td>$7</td></tr>};
				$i++;
			}
			$scantext .= "</table>\n";
		}elsif ($type eq 'News'){
			$scantext .= "<table>\n";
			my $i = 1;
			my $cgi = new CGI;
			my $f = $dbh->prepare("SELECT add_intel(?,?,?,?,?,?,?,?,?,?,-1)");
			while( $file =~ m{top">((?:\w| )+)\D+(\d+)</td><td class="left" valign="top">(.+?)</td></tr>}g){
				my $row = "odd";
				$row = "even" if ($i % 2 == 0);
				$i++;
				my $news = $1;
				my $t = $2;
				my $text = $cgi->escapeHTML($3);
				my $class = '';

				if($news eq 'Launch' && $text =~ m/(?:[^<]*) fleet has been launched, heading for (\d+):(\d+):(\d+), on a mission to (Attack|Defend). Arrival tick: (\d+)/g){

					my $eta = $5 - $t;
					my $mission = $4;
					$mission = 'AllyDef' if $eta == 7 && $x != $1;
					$f->execute($t,$eta,$1,$2,$3,$x,$y,$z,-1,$mission) or print $dbh->errstr;
					$class = qq{ class="$mission"};
				}elsif($news eq 'Incoming' && $text =~ m/We have detected an open jumpgate from (?:[^<]*), located at (\d+):(\d+):(\d+). The fleet will approach our system in tick (\d+) and appears to have roughly (\d+) ships/g){
					my $eta = $4 - $t;
					my $mission = '';
					$mission = 'Defend' if $eta <= 6;
					$mission = 'AllyDef' if $eta == 6 && $x != $1;
					$f->execute($t,$eta,$x,$y,$z,$1,$2,$3,$5,$mission) or print $dbh->errstr;
					$class = qq{ class="$mission"};
				}
				$text =~ s{(\d+):(\d+):(\d+)}{<a href="check?coords=$1:$2:$3">$1:$2:$3</a>}g;
				$scantext .= "<tr class =\"$row\"><td$class>$news</td><td>$t</td><td>$text</td></tr>\n";
			}
			$scantext .= "</table>\n";
		} elsif($type eq 'Unit' || $type eq 'Advanced Unit' || $type eq 'Surface Analysis' || $type eq 'Technology Analysis'){
			$scantext .= "<table>\n";
			my $i = 0;
			my $total = 0;
			my $sec = 0;
			my $dist = 0;
			my $f = $dbh->prepare(qq{SELECT "type","class" FROM ship_stats WHERE name = ?});
			my %visible;
			my %total;
			while($file =~ m{((?:[a-zA-Z]| )+)</t[dh]><td(?: class="right")?>(\d+)}sg){
				$i++;
				my $row = "odd";
				$row = "even" if ($i % 2 == 0);
				$scantext .= "<tr class=\"$row\"><td>$1</td><td>$2</td></tr>\n";
				$total += $2;
				$sec = $2 if ($1 eq 'Security Centre');
				$dist = $2 if ($1 eq 'Wave Distorter');
				$f->execute($1);
				if (my $ship = $f->fetchrow_hashref){
					$total{$ship->{class}} += $2;
					$visible{$ship->{class}} += $2 unless $ship->{type} eq 'Cloak';
				}
			}
			if ($type =~ 'Unit'){
				my $scan .= q{<table>
					<tr><th>Class</th><th>Total</th><th>Visible</th></tr>};
				my $i = 0;
				for my $type (qw/Fighter Corvette Frigate Destroyer Cruiser Battleship/){
					next unless $total{$type};
					$i++;
					my $row = "odd";
					$row = "even" if ($i % 2 == 0);
					$visible{$type} = 0 unless $visible{$type};
					$scan .= "<tr class=\"$row\"><td>$type</td><td>".$total{$type}."</td><td>".$visible{$type}."</td></tr>\n";
				}
				$scan .= "</table>\n";
				$addScan->execute($tick-1,$scan[0],'Ship Classes',$scan,$planet);
			}
			$scantext .= "<tr class=\"odd\"><td>No</td><td>Ships</td></tr>\n" unless $i;
			$scantext .= "</table>\n";

			if($type eq 'Surface Analysis'){
				my $f = $dbh->prepare("UPDATE covop_targets SET structures = ?, sec_centres = ?, dists = ? WHERE planet = ?");
				if ($f->execute($total,$sec,$dist,$planet) < 1){
					$f = $dbh->prepare("INSERT INTO covop_targets (planet,structures, sec_centres, dists) VALUES(?,?,?,?)");
					$f->execute($planet,$total,$sec,$dist);
				}
			}
		} elsif($type eq 'Military'){
			$scantext .= "<table>\n";
			my $i = 1;
			my @totals = (0,0,0,0);
			my @eta = (8,8,8,8);
			my $f = $dbh->prepare(qq{SELECT "type","class" FROM ship_stats WHERE name = ?});
			while($file =~ m/big left">((?:[a-zA-Z]| )+)<\/t[dh]>.*?center>(\d+).*?center>(\d+).*?center>(\d+).*?center>(\d+)/sg){
				next if ($2+$3+$4+$5 == 0);
				my @ships = ($2,$3,$4,$5);
				my $row = "odd";
				my ($type,$class) = $dbh->selectrow_array($f,undef,$1);
				#print "$1 $type\n";
				$row = "even" if ($i % 2 == 0);
				$scantext .= "<tr class=\"$row\"><td>$1</td><td>$2</td><td>$3</td><td>$4</td><td>$5</td></tr>\n";
				$i++;
				unless ($type eq "Cloak"){
					$totals[0] += $2;
					$totals[1] += $3;
					$totals[2] += $4;
					$totals[3] += $5;
				}
				foreach my $i (0,1,2,3){
					if ($ships[$i] > 0 && $eta[$i] < 9 && ($class =~ /Frigate|Destroyer/)){
						$eta[$i] = 9;
					}elsif ($ships[$i] > 0 && $eta[$i] < 10 && ($class =~ /Cruiser|Battleship/)){
						$eta[$i] = 10;
					}
				}
			}
			$scantext .= "<tr class=\"total\"><td>Total uncloaked</td><td>$totals[0]</td><td>$totals[1]</td><td>$totals[2]</td><td>$totals[3]</td></tr>\n";
			$scantext .= "<tr><td>Initial eta</td><td>$eta[0]</td><td>$eta[1]</td><td>$eta[2]</td><td>$eta[3]</td></tr>\n";
			$scantext .= "</table>\n";
		}
		unless ($scantext || $type eq 'Incoming'){
			print "Something wrong with scan $scan[0] type $type at tick $tick";
		}
		$update->execute($tick,$type,$scantext,$planet,$scan[0],$scan[1]) or warn DBI->errstr;
	}else{
		my $f = $dbh->prepare('UPDATE users SET scan_points = scan_points - 1 WHERE uid = ? ');
		$f->execute($scan[2]);
		$delscan->execute($scan[0],$scan[1]);
	}
}
$dbh->disconnect;
