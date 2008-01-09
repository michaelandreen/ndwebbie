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

package NDWeb::Pages::AddIntel;
use strict;
use warnings;
use CGI qw/:standard/;
use NDWeb::Forum;
use NDWeb::Include;

use base qw/NDWeb::XMLPage/;

$NDWeb::Page::PAGES{addintel} = 'NDWeb::Pages::AddIntel';

sub render_body {
	my $self = shift;
	my ($BODY) = @_;

	my $DBH = $self->{DBH};

	$self->{TITLE} = 'Add Intel and Scans';

	my $error;

	return $self->noAccess unless $self->isMember;

	if (defined param('cmd')){
		if (param('cmd') eq 'submit' || param('cmd') eq 'submit_message'){
			my $findscan = $DBH->prepare(q{SELECT scan_id FROM scans WHERE scan_id = ? AND tick >= tick() - 168 AND groupscan = ?});
			my $addscan = $DBH->prepare(q{INSERT INTO scans (scan_id,tick,uid,groupscan) VALUES (?,tick(),?,?)});
			my $addpoint = $DBH->prepare(q{UPDATE users SET scan_points = scan_points + 1 WHERE uid = ? });
			my $intel = param('intel');
			my @scans;
			while ($intel =~ m{http://[\w.]+/.+?scan(_id|_grp)?=(\d+)}g){
				my $groupscan = (defined $1 && $1 eq '_grp') || 0;
				my %scan;
				$scan{Scan} = $2;
				$scan{Message} = ($groupscan ? b 'Group':'')."Scan $2: ";
				$findscan->execute($2,$groupscan);
				if ($findscan->rows == 0){
					if ($addscan->execute($2,$ND::UID,$groupscan)){
						$addpoint->execute($ND::UID) unless $groupscan;
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
			$tick = param('tick') if defined param('tick') 
				&& param('tick') =~ /^(\d+)$/;
			my $addintel = $DBH->prepare(q{INSERT INTO fleets 
				(name,mission,tick,target,sender,eta,amount,ingal,back,uid)
				VALUES($1,$2,$3,planetid($4,$5,$6,$10),planetid($7,$8,$9,$10)
					,$11,$12,$13,$14,$15)
			});
			my $findplanet = $DBH->prepare(q{SELECT planetid(?,?,?,?)});
			while ($intel =~ m/(\d+):(\d+):(\d+)\*?\s+(\d+):(\d+):(\d+)
				\*?\s+(.+)(?:Ter|Cat|Xan|Zik|Etd)?
				\s+(\d+)\s+(Attack|Defend)\s+(\d+)/gx){
				my $ingal = ($1 == $4 && $2 == $5) || 0;
				my $lt = $tick + $10;
				my $back = ($ingal ? $lt + 4 : undef);
				warn "Added: $&\n";
				$addintel->execute($7,$9,$lt,$1,$2,$3,$4,$5,$6,$tick,$10,$8
					,$ingal,$back, $ND::UID) or warn $DBH->errstr;
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
				$error .= 'Intel message added' if addForumPost $DBH,$thread,$ND::UID,param('intel')
			}
		}
	}
	$BODY->param(Tick => $self->{TICK});
	$BODY->param(Error => $error);
	return $BODY;
}
1;
