use strict;
use warnings;
use Test::More tests => 3;
use WWW::YouTube::Download;

do {
    no warnings 'redefine';
    *LWP::UserAgent::get = sub {
        my ($self, $uri) = @_;
        HTTP::Response->new(200, 'OK', [], 'status%3Dok%26itag%3D37%26itag%3D22%26itag%3D35%26itag%3D34%26itag%3D5%26video_id%3DEXAMPLE%26token%3DTOKEN%26title%3DSample');
    };
};

my $video_id = 'EXAMPLE';

my $client = new_ok 'WWW::YouTube::Download';

ok my $data = $client->prepare_download($video_id);
is_deeply $data, +{
    video_id  => $video_id,
    video_url => "http://www.youtube.com/get_video?video_id=$video_id&t=TOKEN",
    title     => 'Sample',
    fmt       => '37',
    suffix    => '.mp4',
};

done_testing;
