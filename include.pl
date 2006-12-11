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


sub isMember {
	return exists $ND::GROUPS{Members};
}

sub isHC {
	return exists $ND::GROUPS{HC};
}

sub isDC {
	return exists $ND::GROUPS{DC};
}

sub isBC {
	return exists $ND::GROUPS{BC};
}

sub parseMarkup {
	my ($text) = @_;

	$text =~ s{\n}{\n<br/>}g;
	$text =~ s{\[B\](.*?)\[B\]}{<b>$1</b>};
	return $text;
}

1;
