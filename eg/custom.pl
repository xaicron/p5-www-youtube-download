use strict;
use warnings;
use WWW::YouTube::Download;

my $video_id = shift || die "Usage: $0 [video_id|video_url]";

my $client = WWW::YouTube::Download->new(encode => 'cp932');
my $url = $client->get_video_url($video_id);

$client->user_agent->get($url, ':content_file' => $client->filename);
