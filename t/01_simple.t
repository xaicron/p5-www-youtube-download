use strict;
use warnings;
use Test::More tests => 9;
use WWW::YouTube::Download;

do {
    my $content = do {
        open my $fh, '<', 't/01_data.txt' or die $!;
        local $/;
        <$fh>;
    };

    my $contents = [$content];

    no warnings 'redefine';
    *LWP::UserAgent::get = sub {
        my ($self, $uri) = @_;
        HTTP::Response->new(200, 'OK', [], shift @$contents);
    };
};

my $video_id = 'foo';

my $client = new_ok 'WWW::YouTube::Download';

ok my $data = $client->prepare_download($video_id);
is_deeply $data, +{
    'video_id'      => $video_id,
    'fmt_list'      => [ '34', '18', '5' ],
    'suffix'        => '.flv',
    'title'         => 'の手書きで魔法少女まどか☆マギカＯＰ.mp4',
    'fmt'           => '34',
    'video_url'     => 'http://v9.lscache1.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor%2Coc%3AU0dYTlFUUV9FSkNNOF9JTlVD&algorithm=throttle-factor&itag=34&ipbits=0&burst=40&sver=3&signature=4D216F61C63A1B9DDDD3A837F3EFFCBCDA06297B.ABC59F7AAB4A47CC938CB6833A014701666234CA&expire=1299193200&key=yt1&ip=0.0.0.0&factor=1.25&id=48334a2162ac9611',
    'video_url_map' => {
        '34' => {
            'suffix'     => '.flv',
            'url'        => 'http://v9.lscache1.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor%2Coc%3AU0dYTlFUUV9FSkNNOF9JTlVD&algorithm=throttle-factor&itag=34&ipbits=0&burst=40&sver=3&signature=4D216F61C63A1B9DDDD3A837F3EFFCBCDA06297B.ABC59F7AAB4A47CC938CB6833A014701666234CA&expire=1299193200&key=yt1&ip=0.0.0.0&factor=1.25&id=48334a2162ac9611',
            'resolution' => '640x360',
            'fmt'        => '34',
        },
        '18' => {
            'suffix'     => '.mp4',
            'url'        => 'http://v21.lscache4.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor%2Coc%3AU0dYTlFUUV9FSkNNOF9JTlVD&algorithm=throttle-factor&itag=18&ipbits=0&burst=40&sver=3&signature=B38170914BA6288E84041B3BFAE6E4ED67F7E688.A5810CB3FC25AD29129D3006F907ECFB6D445FCA&expire=1299193200&key=yt1&ip=0.0.0.0&factor=1.25&id=48334a2162ac9611',
            'resolution' => '640x360',
            'fmt'        => '18',
        },
        '5' => {
            'suffix'     => '.flv',
            'url'        => 'http://v7.lscache8.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor%2Coc%3AU0dYTlFUUV9FSkNNOF9JTlVD&algorithm=throttle-factor&itag=5&ipbits=0&burst=40&sver=3&signature=9326AF57BFE993192A793A4FB441784404B73370.CE3BBF8A9C369A6E74C699B767783E0CAECE66B7&expire=1299193200&key=yt1&ip=0.0.0.0&factor=1.25&id=48334a2162ac9611',
            'resolution' => '320x240',
            'fmt'        => '5',
        },
    },
};

is $client->get_video_id($video_id), $video_id;
is $client->get_video_url($video_id), 'http://v9.lscache1.c.youtube.com/videoplayback?sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor%2Coc%3AU0dYTlFUUV9FSkNNOF9JTlVD&algorithm=throttle-factor&itag=34&ipbits=0&burst=40&sver=3&signature=4D216F61C63A1B9DDDD3A837F3EFFCBCDA06297B.ABC59F7AAB4A47CC938CB6833A014701666234CA&expire=1299193200&key=yt1&ip=0.0.0.0&factor=1.25&id=48334a2162ac9611';
is $client->get_title($video_id), 'の手書きで魔法少女まどか☆マギカＯＰ.mp4';
is $client->get_fmt($video_id), '34';
is_deeply $client->get_fmt_list($video_id), ['34', '18', '5'];
is $client->get_suffix($video_id), '.flv';

done_testing;

__END__
