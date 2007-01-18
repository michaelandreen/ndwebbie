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

package ND::Web::Pages::AddIntel;
use strict;
use warnings FATAL => 'all';
use CGI qw/:standard/;
use ND::Web::Forum;
use ND::Web::Include;

our @ISA = qw/ND::Web::XMLPage/;

$ND::Web::Page::PAGES{addintel} = 'ND::Web::Pages::AddIntel';

sub render_body {
	my $self = shift;
	my ($BODY) = @_;

	my $DBH = $self->{DBH};

	$self->{TITLE} = 'Add Intel and Scans';

	my $error;

	return $self->noAccess unless $self->isMember;

	if (defined param('cmd')){
		if (param('cmd') eq 'submit' || param('cmd') eq 'submit_message'){
			my $findscan = $DBH->prepare("SELECT scan_id FROM scans WHERE scan_id = ? AND tick >= tick() - 48");
			my $addscan = $DBH->prepare('INSERT INTO scans (scan_id,tick,"type") VALUES (?,tick(),?)');
			my $addpoint = $DBH->prepare('UPDATE users SET scan_points = scan_points + 1 WHERE uid = ? ');
			my $intel = param('intel');
			my @scans;
			while ($intel =~ m/http:\/\/game.planetarion.com\/showscan.pl\?scan_id=(\d+)/g){
				my %scan;
				$scan{Scan} = $1;
				$scan{Message} = "Scan $1: ";
				$findscan->execute($1);
				if ($findscan->rows == 0){
					if ($addscan->execute($1,$ND::UID)){
						$addpoint->execute($ND::UID);
						$scan{Message} .= '<i>added</i>';
					}else{
						$scan{Message} .= "<b>something went wrong:</b> <i>$DBH->errstr</i>";
					}
				}else{
					$scan{Message} .= '<b>already exists</b>';
				}
				push @scans,\%scan;
			}
			$BODY->param(Scans => \@scans);
			my $tick = $self->{TICK};
			$tick = param('tick') if $tick =~ /^(\d+)$/;
			my $addintel = $DBH->prepare(qq{SELECT add_intel(?,?,?,?,?,?,?,?,?,?,?)});
			while ($intel =~ m/(\d+):(\d+):(\d+)\*?\s+(\d+):(\d+):(\d+)\*?\s+.+(?:Ter|Cat|Xan|Zik)?\s+(\d+)\s+(Attack|Defend)\s+(\d+)/g){
				$addintel->execute($tick,$9, $1,$2,$3,$4,$5,$6,$7,$8,$ND::UID) or $error .= $DBH->errstr;
			}
		}
		if (param('cmd') eq 'submit_message'){
			my $board = {id => 12};
			my $subject = param('subject');
			unless ($subject){
				if (param('intel') =~ /(.*\w.*)/){
					$subject = $1;
				}

			}
			if (my $thread = addForumThread $DBH,$board,$ND::UID,$subject){
				$error .= p 'Intel message added' if addForumPost $DBH,$thread,$ND::UID,param('intel')
			}
		}
	}
	$BODY->param(Tick => $self->{TICK});
	$BODY->param(Error => $error);
	return $BODY;
}
1;
