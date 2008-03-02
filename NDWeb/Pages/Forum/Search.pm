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

package NDWeb::Pages::Forum::Search;
use strict;
use warnings;
use NDWeb::Forum;
use CGI qw/:standard/;
use NDWeb::Include;
use ND::Include;

use base qw/NDWeb::Pages::Forum/;

sub render_body {
	my $self = shift;
	my ($BODY) = @_;
	my $DBH = $self->{DBH};
	$self->{TITLE} = 'Forum';
	my @queries;
	if (param('search')){
		push @queries,'('.param('search').')';
	}
	my %cat = (body => 'D', topic => 'A', author => 'B');
	for ('body','topic','author'){
		if (param($_)){
			my @words = split /\W+/,param($_);
			my $op = param('all'.$_) ? '&' : '|';
			my $cat = $cat{$_};
			my $query = join " $op ", map {"$_:$cat"} @words;
			push @queries,"($query)";
		}
	}
	my $search = join ' & ', @queries;

	if ($search){
		my $posts = $DBH->prepare(q{SELECT fp.ftid,u.username,ft.subject
			,ts_headline(fp.message,to_tsquery($2)) AS headline
			,ts_rank_cd(fp.textsearch, to_tsquery($2),32) AS rank
			FROM forum_boards fb 
				JOIN forum_threads ft USING (fbid)
				JOIN forum_posts fp USING (ftid)
				JOIN users u ON fp.uid = u.uid
			WHERE fb.fbid IN (SELECT fbid FROM forum_access 
					WHERE gid IN (SELECT groups($1)))
				AND fp.textsearch @@@ to_tsquery($2)
			ORDER BY rank DESC
		}) or warn $DBH->errstr;
		$posts->execute($ND::UID,$search) or warn escapeHTML $DBH->errstr;
		my @posts;
		while (my $post = $posts->fetchrow_hashref){
			push @posts,$post;
		}
		$BODY->param(SearchResult => \@posts);
	}
	return $BODY;
}

1;
