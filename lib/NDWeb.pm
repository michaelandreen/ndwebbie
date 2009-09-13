package NDWeb;

use strict;
use warnings;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use parent qw/Catalyst/;
use Catalyst qw/
	-Debug
	ConfigLoader
	Static::Simple
	Unicode

	Authentication
	Authentication::Store::NDWeb
	Authentication::Credential::Password

	Authorization::Roles
	Authorization::ACL

	Session::DynamicExpiry
	Session
	Session::Store::File
	Session::State::Cookie

	Compress::Gzip
	Compress::Deflate

	Cache
	PageCache
/;

our $VERSION = '0.01';

sub signal_bots {
	system 'killall','-USR1', 'ndbot.pl';
}

# Configure the application.
#
# Note that settings in ndweb.yml (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config( name => 'NDWeb' );
__PACKAGE__->config->{'Plugin::Authentication'}{'use_session'} = 1;
__PACKAGE__->config(session => {
	storage => "/tmp/ndweb-$>/session",
	directory_umask => 077,
	expires => 300,
	verify_address => 1,
});
__PACKAGE__->config( cache => {
	backend => {
		class => "Cache::FileCache",
		cache_root => "/tmp/ndweb-$>",
		namespace => "cache",
		default_expires_in => 3600,
		directory_umask => 077,
	},
});

__PACKAGE__->config( page_cache => {
	set_http_headers => 1,
	disable_index => 1,
});

__PACKAGE__->config( default_model => 'Model');
# Start the application
__PACKAGE__->setup();

__PACKAGE__->deny_access_unless('/users',[qw/admin_users/]);
__PACKAGE__->deny_access_unless('/alliances',[qw/alliances/]);
__PACKAGE__->deny_access_unless('/alliances/resources',[qw/alliances_resources/]);
__PACKAGE__->deny_access_unless('/graphs/alliancevsintel',[qw/graphs_intel/]);
__PACKAGE__->deny_access_unless('/graphs/avgalliancevsintel',[qw/graphs_intel/]);
__PACKAGE__->deny_access_unless('/members',[qw/members/]);
__PACKAGE__->deny_access_unless('/members/defenders',[qw/members_defenders/]);
__PACKAGE__->deny_access_unless('/covop',[qw/covop/]);
__PACKAGE__->deny_access_unless('/calls',[qw/calls_edit/]);
__PACKAGE__->allow_access_if('/calls/index',[qw/calls_list/]);
__PACKAGE__->allow_access_if('/calls/list',[qw/calls_list/]);
__PACKAGE__->allow_access_if('/calls/edit',[qw/members/]);
__PACKAGE__->allow_access_if('/calls/findCall',[qw/members/]);
__PACKAGE__->deny_access_unless('/raids',[qw/raids_edit/]);
__PACKAGE__->allow_access_if('/raids/index',[qw//]);
__PACKAGE__->allow_access_if('/raids/view',[qw//]);
__PACKAGE__->allow_access_if('/raids/targetcalc',[qw//]);
__PACKAGE__->allow_access_if('/raids/fleetcalc',[qw//]);
__PACKAGE__->allow_access_if('/raids/calcredir',[qw//]);
__PACKAGE__->allow_access_if('/raids/findRaid',[qw//]);
__PACKAGE__->allow_access_if('/raids/log',[qw//]);
__PACKAGE__->deny_access_unless('/intel',[qw/intel/]);
__PACKAGE__->deny_access_unless('/intel/members',[qw/intel_members/]);
__PACKAGE__->deny_access_unless('/intel/member',[qw/intel_member/]);
__PACKAGE__->deny_access_unless('/intel/naps',[qw/intel_naps/]);
__PACKAGE__->deny_access_unless('/jsrpc',[qw//]);
__PACKAGE__->allow_access_if('/jsrpc/end',1);
__PACKAGE__->deny_access_unless('/forum/allUnread',[qw//]);
__PACKAGE__->deny_access_unless('/forum/privmsg',[qw//]);
__PACKAGE__->deny_access_unless('/settings',[qw//]);
__PACKAGE__->deny_access_unless('/textexport/alliance',[qw/textexport_alliance/]);

=head1 NAME

NDWeb - Catalyst based application

=head1 SYNOPSIS

    script/ndweb_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<NDWeb::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
