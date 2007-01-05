use lib qw(/var/www/ndawn/code/);

use POSIX;

use CGI qw/:standard/;
use HTML::Template;

use Apache::DBI();
DBI->install_driver("Pg");
use DBI;
use DBD::Pg qw(:pg_types);

use ND::DB;
use ND::Include;
use ND::Web::Include;
use ND::Web::Forum;

use Tie::File;


1;
