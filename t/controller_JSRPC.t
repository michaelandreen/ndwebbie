use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'NDWeb' }
BEGIN { use_ok 'NDWeb::Controller::JSRPC' }

ok( request('/jsrpc')->is_success, 'Request should succeed' );


