use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'NDWeb' }
BEGIN { use_ok 'NDWeb::Controller::Members' }

ok( request('/members')->is_success, 'Request should succeed' );


