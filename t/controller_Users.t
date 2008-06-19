use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'NDWeb' }
BEGIN { use_ok 'NDWeb::Controller::Users' }

ok( request('/users')->is_success, 'Request should succeed' );


