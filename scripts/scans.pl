#!/usr/bin/perl
#**************************************************************************
#   Copyright (C) 2006,2007 by Michael Andreen <harvATruinDOTnu>          *
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
no warnings 'exiting';
use CGI;
use DBI;
use DBD::Pg qw(:pg_types);
use LWP::Simple;

use FindBin;
use lib "$FindBin::Bin/../lib";

use ND::DB;

our $dbh = ND::DB::DB();

#$dbh->trace("1","/tmp/scanstest");

#my $test = $dbh->prepare(q{INSERT INTO scans (tick,scan_id) VALUES(1,3) RETURNING id});
#print ;
$dbh->do(q{SET CLIENT_ENCODING TO 'LATIN1';});

my $scangroups = $dbh->prepare(q{SELECT id,scan_id,tick,uid FROM scans
	WHERE groupscan AND NOT parsed FOR UPDATE
});
my $oldscan = $dbh->prepare(q{SELECT scan_id FROM scans WHERE scan_id = ? AND tick >= tick() - 168});
my $addScan = $dbh->prepare(q{INSERT INTO scans (scan_id,tick,uid) VALUES (?,?,?)});
my $parsedscan = $dbh->prepare(q{UPDATE scans SET tick = ?, type = ?, planet = ?, parsed = TRUE WHERE id = ?});
my $addpoints = $dbh->prepare(q{UPDATE users SET scan_points = scan_points + ? WHERE uid = ? });
my $delscan = $dbh->prepare(q{DELETE FROM scans WHERE id = ?});

$scangroups->execute or die $dbh->errstr;

while (my $group = $scangroups->fetchrow_hashref){
	$dbh->begin_work;
	my $file = get("http://game.planetarion.com/showscan.pl?scan_grp=$group->{scan_id}");

	my $points = 0;
	while ($file =~ m/showscan.pl\?scan_id=(\d+)/g){
		unless ($dbh->selectrow_array($oldscan,undef,$1)){
			$addScan->execute($1,$group->{tick},$group->{uid});
			++$points;
		}
	}
	$addpoints->execute($points,$group->{uid});
	$parsedscan->execute($group->{tick},'GROUP',undef,$group->{id});
	$dbh->commit;
}

my $newscans = $dbh->prepare(q{SELECT id,scan_id,tick,uid FROM scans
	WHERE NOT groupscan AND NOT parsed FOR UPDATE
});
my $findplanet = $dbh->prepare(q{SELECT planetid(?,?,?,?)});
my $findoldplanet = $dbh->prepare(q{SELECT id FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND tick <= $4 ORDER BY tick DESC LIMIT 1});
my $findcoords = $dbh->prepare(q{SELECT * FROM planetcoords(?,?)});
my $addfleet = $dbh->prepare(q{INSERT INTO fleets (name,mission,planet,amount) VALUES(?,?,?,?) RETURNING fid});
my $fleetscan = $dbh->prepare(q{INSERT INTO fleet_scans (fid,id) VALUES(?,?)});
my $addintel = $dbh->prepare(q{INSERT INTO intel (name,mission,sender,target,tick,eta,back,amount,ingal,uid)
	VALUES(?,?,?,?,?,?,?,?,?,-1) RETURNING id});
my $intelscan = $dbh->prepare(q{INSERT INTO fleet_scans (intel,id) VALUES(?,?)});
my $addships = $dbh->prepare(q{INSERT INTO fleet_ships (id,ship,amount) VALUES(?,?,?)});
my $addplanetscan = $dbh->prepare(q{INSERT INTO planet_scans
	(id,tick,planet,metal_roids,metal,crystal_roids,crystal,eonium_roids,eonium
		,agents,guards,light,medium,heavy,hidden)
	VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)});

sub parse_planet {
	my ($scan,$file) = @_;

	my @values = ($scan->{id},$scan->{tick},$scan->{planet});
	$file =~ s/(\d),(\d)/$1$2/g;

	while($file =~ m/"center">(Metal|Crystal|Eonium)\D+(\d+)\D+([\d,]+)/g){
		push @values,$2,$3;
	}
	if($file =~ m{Security\ Guards .+? "center">(\d+)</td>
			.+? "center">(\d+)</td>}sx){
		push @values,$1,$2;
	}
	if($file =~ m{<td class="center">([A-Z][a-z]+)</td><td class="center">([A-Z][a-z]+)</td><td class="center">([A-Z][a-z]+)</td>}){
		push @values,$1,$2,$3;
	}
	if($file =~ m{<span class="superhighlight">([\d,]+)</span>}){
		push @values,$1;
	}
	$addplanetscan->execute(@values);
}

sub parse_incoming {
	my ($scan,$file) = @_;

	while($file =~ m{class="left">Fleet:\s(.*?)</td><td\sclass="right">
			Mission:\s(\w+)</td></tr>(.*?)Total\sShips:\s(\d+)}sxg){
		my $id = addfleet($1,$2,$3,$scan->{planet},$scan->{tick},$4);
		$fleetscan->execute($id,$scan->{id}) or die $dbh->errstr;
	}
}

sub parse_unit {
	my ($scan,$file) = @_;

	my $id = addfleet($scan->{type},'Full fleet',$file,$scan->{planet},$scan->{tick});
	$fleetscan->execute($id,$scan->{id}) or die $dbh->errstr;
}

sub parse_jumpgate {
	my ($scan,$file) = @_;

	while ($file =~ m{(\d+):(\d+):(\d+)\D+(Attack|Defend|Return)</td><td class="left">([^<]*)\D+(\d+)\D+(\d+)}g){
		my ($sender) = $dbh->selectrow_array($findplanet,undef,$1,$2,$3,$scan->{tick});
		($sender) = $dbh->selectrow_array($findoldplanet,undef,$1,$2,$3,$scan->{tick})
			if ((not defined $sender) && $4 eq 'Return');
		my $id = addintel($5,$4,$sender,$scan->{planet},$scan->{tick}+$6,$6
			,undef,$7, $scan->{x} == $1 && $scan->{y} == $2);
		$intelscan->execute($id,$scan->{id});
	}

}

my $adddevscan = $dbh->prepare(q{INSERT INTO development_scans
	(id,tick,planet,light_fac,medium_fac,heavy_fac,amps,distorters
		,metal_ref,crystal_ref,eonium_ref,reslabs,fincents,seccents
		,travel,infra,hulls,waves,extraction,covert,mining,total)
	VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	});


my %parsers = (
	Planet => \&parse_planet,
	Incoming => \&parse_incoming,
	Unit => \&parse_unit,
	'Advanced Unit' => \&parse_unit,
	Jumpgate => \&parse_jumpgate,
);


$dbh->begin_work or die 'No transaction';
$newscans->execute or die $dbh->errstr;
$dbh->pg_savepoint('scans') or die "No savepoint";

my $parsedscans = 0;

while (my $scan = $newscans->fetchrow_hashref){
	$dbh->pg_release('scans') or die "Couldn't save";
	$dbh->pg_savepoint('scans') or die "Couldn't save";
	my $file = get("http://game.planetarion.com/showscan.pl?scan_id=$scan->{scan_id}");
	next unless defined $file;
	if ($file =~ /((?:\w| )*) (?:Scan|Probe) on (\d+):(\d+):(\d+) in tick (\d+)/){
		eval {
		my $type = $1;
		my $x = $2;
		my $y = $3;
		my $z = $4;
		my $tick = $5;
		$scan->{tick} = $5;
		$scan->{type} = $1;
		$scan->{x} = $x;
		$scan->{y} = $y;

		if($dbh->selectrow_array(q{SELECT * FROM scans WHERE scan_id = ? AND tick = ? AND id <> ?},undef,$scan->{scan_id},$tick,$scan->{id})){
			$dbh->pg_rollback_to('scans') or die "rollback didn't work";
			$delscan->execute($scan->{id});
			$addpoints->execute(-1,$scan->{uid}) if $scan->{uid} > 0;
			warn "Duplicate scan: $scan->{id} http://game.planetarion.com/showscan.pl?scan_id=$scan->{scan_id}\n";
			next;
		}
		my ($planet) = $dbh->selectrow_array($findplanet,undef,$x,$y,$z,$tick);
		$scan->{planet} = $planet;
		unless ($planet){
			$dbh->pg_rollback_to('scans') or die "rollback didn't work";
			if ( $x == 0 && $y == 0 && $z == 0 ){
				$delscan->execute($scan->{id});
				$addpoints->execute(-1,$scan->{uid}) if $scan->{uid} > 0;
			}
			next;
		}
		my $scantext = "";
		if ($file =~ /(Note: [^<]*)/){
			#TODO: something about planet being closed?
		}
		if (exists $parsers{$type}){
			$parsers{$type}->($scan,$file);
		}elsif ($type eq 'News'){
			while( $file =~ m{top">((?:\w| )+)\D+(\d+)</td><td class="left" valign="top">(.+?)</td></tr>}g){
				my $news = $1;
				my $t = $2;
				my $text = $3;
				my ($x,$y,$z) = $dbh->selectrow_array($findcoords,undef,$planet,$t);
				die "No coords for: $planet tick $t" unless defined $x;
				if($news eq 'Launch' && $text =~ m/The (.*?) fleet has been launched, heading for (\d+):(\d+):(\d+), on a mission to (Attack|Defend). Arrival tick: (\d+)/g){
					my $eta = $6 - $t;
					my $mission = $5;
					my $back = $6 + $eta;
					$mission = 'AllyDef' if $eta == 6 && $x != $2;
					my ($target) = $dbh->selectrow_array($findplanet,undef
						,$2,$3,$4,$t) or die $dbh->errstr;
					die "No target: $2:$3:$4" unless defined $target;
					my $id = addintel($1,$mission,$planet,$target,$6
						,$eta,$back,undef, ($x == $2 && $y == $3));
					$intelscan->execute($id,$scan->{id});
				}elsif($news eq 'Incoming' && $text =~ m/We have detected an open jumpgate from (.*?), located at (\d+):(\d+):(\d+). The fleet will approach our system in tick (\d+) and appears to have roughly (\d+) ships/g){
					my $eta = $5 - $t;
					my $mission = '';
					my $back = $5 + $eta;
					$mission = 'Defend' if $eta <= 6;
					$mission = 'AllyDef' if $eta == 6 && $x != $2;
					my ($target) = $dbh->selectrow_array($findplanet,undef
						,$2,$3,$4,$t) or die $dbh->errstr;
					die "No target: $2:$3:$4" unless defined $target;
					my $id = addintel($1,$mission,$target,$planet,$5
						,$eta,$back,$6, ($x == $2 && $y == $3));
					$intelscan->execute($id,$scan->{id});
				}
			}
		} elsif($type eq 'Development'){
			my @values = ($scan->{id},$tick,$planet);
			my $total = 0;
			while($file =~ m{((?:[a-zA-Z]| )+)</t[dh]><td(?: class="right")?>(\d+)}sg){
				push @values,$2;
				$total += $2 if $#values <= 13;
			}
			push @values,$total;
			$adddevscan->execute(@values);
		} elsif($type eq 'Landing'){
		} else {
			print "Something wrong with scan $scan->{id} type $type at tick $tick http://game.planetarion.com/showscan.pl?scan_id=$scan->{scan_id}\n";
		}
		$parsedscan->execute($tick,$type,$planet,$scan->{id}) or die $dbh->errstr;
		#$dbh->rollback;
		++$parsedscans;
		};
		if ($@) {
			warn $@;
			$dbh->pg_rollback_to('scans') or die "rollback didn't work";
		}
	}else{
		warn "Nothing useful in scan: $scan->{id} http://game.planetarion.com/showscan.pl?scan_id=$scan->{scan_id}\n";
		$delscan->execute($scan->{id});
		$addpoints->execute(-1,$scan->{uid}) if $scan->{uid} > 0;
	}
}
#$dbh->rollback;
$dbh->commit;

system 'killall','-USR1', 'irssi' if $parsedscans;

sub addfleet {
	my ($name,$mission,$ships,$sender,$tick,$amount) = @_;

	my @ships;
	my $total = 0;
	while(defined $ships && $ships =~ m{((?:[a-zA-Z]| )+)</td><td(?: class="right")?>(\d+)}sg){
		$total += $2;
		push @ships, [$1,$2];
	}
	$amount = $total if (!defined $amount);
	my $id = $dbh->selectrow_array($addfleet,undef,$name,$mission,$sender
		,$tick, $amount);
	for my $s (@ships){
		unshift @{$s},$id;
		$addships->execute(@{$s}) or die $dbh->errstr;
	}
	return $id;
}

sub addintel {
	my ($name,$mission,$sender,$target,$tick,$eta,$back,$amount,$ingal) = @_;

	die "no sender" unless defined $sender;

	$ingal = 0 unless $ingal;
	$back = $tick + 4 if $ingal && $eta <= 4;

	if ($mission eq 'Return'){
		($sender,$target) = ($target,$sender);
		$back = $tick + $eta if $eta;
	}

	my $id = $dbh->selectrow_array($addintel,undef,$name,$mission,$sender
		,$target,$tick, $eta, $back, $amount,$ingal);
	return $id;
}
