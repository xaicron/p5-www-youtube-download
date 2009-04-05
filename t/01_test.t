use strict;
use Test::More tests => 3;
use Test::Exception;

use WWW::YouTube::Download;

my $client = WWW::YouTube::Download->new;

isa_ok $client, 'WWW::YouTube::Download';

dies_ok { $client->get_video_url };
dies_ok { $client->download };
