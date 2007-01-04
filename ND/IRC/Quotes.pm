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
package ND::IRC::Quotes;
use strict;
use warnings;
use ND::IRC::Access;
use Tie::File;
use File::Temp ();
require Exporter;

our @ISA = qw/Exporter/;

our @EXPORT = qw/quote addQuote lastQuote findQuote delQuote/;

tie our @FILE, 'Tie::File', "/home/ndawn/.eos/scripts/quote.txt";
tie our @OLDFILE, 'Tie::File',"/home/ndawn/.eos/scripts/oldquotes.txt" or die "test";

sub quote {
	my ($n) = @_;
	$n = $n-1 if defined $n;
	$n = int(rand($#FILE)) unless defined $n;
	my $text = $FILE[$n];
	$text =~ s/(.*?)[\r\n]*$/$1/;
	$n++;
	my $num = $#FILE+1;
	$ND::server->command("msg $ND::target Quote $ND::B$n$ND::B of $ND::B$num:$ND::B $text");
}

sub addQuote {
	my ($quote) = @_;
	push @FILE, $quote;
	my $num = $#FILE+1;
	$ND::server->command("msg $ND::target Quote $ND::B$num$ND::B added");
}
sub lastQuote {
	my $n = $#FILE;
	my $text = $FILE[$n];
	$text =~ s/(.*?)[\r\n]*$/$1/;
	$n++;
	$ND::server->command("msg $ND::target Quote $ND::B$n$ND::B of $ND::B$n:$ND::B $text");
}
sub findQuote {
	my ($type,$pattern) = @_;
	my $matcher;
	if ($type eq 'qre'){
		if (defined (eval 'm/$pattern/ix')){
			$matcher = 'm/$pattern/ix';
		}else {
			$ND::server->command("msg $ND::target bad regexp");
			close FILE;
			return;
		}
	}else{
		$matcher = '(index uc($_), uc($pattern)) != -1';
	}
	#mkdir "/tmp/quotes";
	#my $file = "/tmp/quotes/$ND::address.txt";
	#open(FILE,'>',"$file");
	my $file = new File::Temp( SUFFIX => '.txt' );
	my $n = 1;
	my $match = 0;
	for $_ (@FILE){
		chomp;
		if (eval $matcher){
			$match = 1;
			print $file "$n: $_\n";
		}
		$n++;
	}
	if ($match){
		$ND::server->command("dcc send $ND::nick $file");
	}else{
		$ND::server->command("msg $ND::target $ND::nick: No quotes matching that.");
	}
}
sub delQuote {
	my ($n) = @_;
	if (hc){
		$n = $n-1;
		if (exists $FILE[$n]){
			my ($uid,$username) = $ND::DBH->selectrow_array(q{SELECT uid,username FROM users where hostmask ILIKE ?}
				,undef,$ND::address);
			my $text = $FILE[$n];
			push @OLDFILE,"Removed by $username ($uid): $text";
			splice @FILE,$n,1;
			$n++;
			my $num = $#FILE+1;
			$ND::server->command("msg $ND::target Quote $ND::B$n$ND::B {$text} removed, number of quotes now: $ND::B$num$ND::B");
		}else{
			$ND::server->command("msg $ND::target No such quote.");
		}
	}else{
		$ND::server->command("msg $ND::target You don't have access to that!");
	}
}

1;
