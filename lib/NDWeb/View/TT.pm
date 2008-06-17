package NDWeb::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config({
	INCLUDE_PATH => [
		NDWeb->path_to( 'root', 'src' ),
		NDWeb->path_to( 'root', 'lib' )
	],
	PRE_PROCESS  => 'config/main.tt2',
	WRAPPER      => 'site/wrapper.tt2',
	ERROR        => 'error.tt2',
	TIMER        => 0,
	#DEBUG        => 'undef',
	TEMPLATE_EXTENSION => '.tt2',
	#CACHE_SIZE => 256,
});

=head1 NAME

NDWeb::View::TT - Catalyst TTSite View

=head1 SYNOPSIS

See L<NDWeb>

=head1 DESCRIPTION

Catalyst TTSite View.

=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

