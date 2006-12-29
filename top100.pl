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
use warnings FATAL => 'all';
no warnings qw(uninitialized);

$ND::TEMPLATE->param(TITLE => 'Top100 ');

our $BODY;
our $DBH;
our $LOG;

$BODY->param(isHC => isHC());


die "You don't have access" unless isMember();

my $offset = 0;
if (param('offset') =~ /^(\d+)$/){
	$offset = $1;
}
$BODY->param(Offset => $offset);
$BODY->param(PrevOffset => $offset - 100);
$BODY->param(NextOffset => $offset + 100);

my $order = 'scorerank';
if (param('order') =~ /^(scorerank|sizerank|valuerank|xprank|hit_us)$/){
	$order = $1;
}
$BODY->param(Order => $order);
$order .= ' DESC' if ($order eq 'hit_us');


my $extra_columns = '';
if (isHC()){
	$extra_columns = ",planet_status,hit_us, alliance,relationship,nick";
}
my $query = $DBH->prepare(qq{SELECT id,coords(x,y,z), ruler, planet,race,
	size, score, value, xp, sizerank, scorerank, valuerank, xprank
	$extra_columns FROM current_planet_stats ORDER BY $order LIMIT 100 OFFSET ?});
$query->execute($offset);
my @planets;
my $i = 0;
while (my ($id,$coords,$ruler,$planet,$race,$size,$score,$value,$xp,$sizerank,$scorerank,$valuerank,$xprank
		,$planet_status,$hit_us,$alliance,$relationship,$nick) = $query->fetchrow){
	my %planet = (Coords => $coords, Planet => "$ruler OF $planet", Race => $race, Size => "$size ($sizerank)"
		, Score => "$score ($scorerank)", Value => "$value ($valuerank)", XP => "$xp ($xprank)");
	if (isHC){
		$planet{HitUs} = $hit_us;
		$planet{Alliance} = "$alliance ($relationship)";
		$planet{Nick} = "$nick ($planet_status)";
		$planet{PlanetStatus} = $planet_status;
		$planet{Relationship} = $relationship;
		$planet{isHC} = 1;
	}
	$i++;
	$planet{ODD} = $i % 2;
	push @planets,\%planet;
}
$BODY->param(Planets => \@planets);

1;
