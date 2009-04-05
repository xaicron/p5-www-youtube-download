use strict;
use warnings;
use WWW::YouTube::Download;

my $video_id = shift || die "Usage: $0 [video_id|video_url]";

my $client = WWW::YouTube::Download->new(encode => 'cp932', verbose => 1);
$client->download($video_id);
