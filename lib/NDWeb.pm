package NDWeb;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

#Need to preload, otherwise the first hit is slow
use CGI qw/:standard/;
escapeHTML('');

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
	
	Session
	Session::Store::File
	Session::State::Cookie
	/);

__PACKAGE__->deny_access_unless('/users',[qw/admin_users/]);

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
