package NDWeb;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a YAML file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use parent qw/Catalyst/;

our $VERSION = '0.01';

# Configure the application. 
#
# Note that settings in ndweb.yml (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config( name => 'NDWeb' );
__PACKAGE__->config->{'Plugin::Authentication'}{'use_session'} = 1;
__PACKAGE__->config(session => {
	storage => "/tmp/ndweb-$>/sesession",
	directory_umask => 077,
	expires => 300,
	verify_address => 1,
});
__PACKAGE__->config( cache => {
	backend => {
		class => "Cache::FileCache",
		cache_root => "/tmp/ndweb-$>",
		directory_umask => 077,
	},
});

__PACKAGE__->config( page_cache => {
	set_http_headers => 1,
});


# Start the application
__PACKAGE__->setup(qw/
	-Debug
	ConfigLoader
	Static::Simple

	Authentication
	Authentication::Store::NDWeb
	Authentication::Credential::Password

	Authorization::Roles
	Authorization::ACL
	
	Session::DynamicExpiry
	Session
	Session::Store::File
	Session::State::Cookie

	Cache
	PageCache
	/);


__PACKAGE__->deny_access_unless('/users',[qw/admin_users/]);
__PACKAGE__->deny_access_unless('/alliances/resources',[qw/alliances_resources/]);
__PACKAGE__->deny_access_unless('/graphs/alliancevsintel',[qw/graphs_intel/]);
__PACKAGE__->deny_access_unless('/graphs/avgalliancevsintel',[qw/graphs_intel/]);
__PACKAGE__->deny_access_unless('/members',[qw/members/]);
__PACKAGE__->deny_access_unless('/covop',[qw/covop/]);
__PACKAGE__->deny_access_unless('/calls/list',[qw/calls_list/]);
__PACKAGE__->deny_access_unless('/calls/postcallcomment',[qw/calls_edit/]);
__PACKAGE__->deny_access_unless('/calls/postcallupdate',[qw/calls_edit/]);
__PACKAGE__->deny_access_unless('/calls/postattackerupdate',[qw/calls_edit/]);
__PACKAGE__->deny_access_unless('/calls/defleeches',[qw/calls_leeches/]);
__PACKAGE__->deny_access_unless('/raids',[qw/raids_edit/]);
__PACKAGE__->allow_access_if('/raids/index',1);
__PACKAGE__->allow_access_if('/raids/view',1);
__PACKAGE__->allow_access_if('/raids/findRaid',1);
__PACKAGE__->allow_access_if('/raids/log',1);
__PACKAGE__->deny_access_unless('/intel',[qw/intel/]);

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

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
