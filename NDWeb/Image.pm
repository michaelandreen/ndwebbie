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

package NDWeb::Image;
use strict;
use warnings;

use base qw/NDWeb::Page/;


sub render {
	my $self = shift;

	my $img;
	eval {
		$img =  $self->render_body;
	};
	if (defined $img){
		if ((my $rc = $self->{R}->meets_conditions) != Apache2::Const::OK){
			$self->{R}->status($rc);
		}else{
			$self->{R}->headers_out->set(Content_Length => length $img);
			$self->{R}->content_type('image/png');
			$self->{R}->rflush;
			binmode STDOUT;
			print $img;
		}
	}elsif(defined $@){
		$self->{R}->content_type('text/plain');
		print $@;
	}
};

1;
