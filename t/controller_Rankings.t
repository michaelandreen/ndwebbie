use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'NDWeb' }
BEGIN { use_ok 'NDWeb::Controller::Rankings' }

ok( request('/rankings')->is_success, 'Request should succeed' );


