#!/usr/bin/perl -w

use strict;
use warnings;

use local::lib;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Cache::FileCache;

my $cache = Cache::FileCache->new({cache_root => "/tmp/ndweb-$<", namespace => 'cache'});

$cache->purge;

