#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Cache::FileCache;

my $cache = new Cache::FileCache({cache_root => "/tmp/ndweb-$<", namespace => 'cache'} );

$cache->purge;

