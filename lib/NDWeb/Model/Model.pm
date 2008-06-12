package NDWeb::Model::Model;
use strict;
use warnings;
use base 'Catalyst::Model::Factory::PerRequest';

__PACKAGE__->config( 
    class       => 'ND::DB',
    constructor => 'DB',
);

1;
