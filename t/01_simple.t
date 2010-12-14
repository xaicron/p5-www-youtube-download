use strict;
use warnings;
use Test::More tests => 3;
use WWW::YouTube::Download;

do {
    my $info = 'title=%E3%80%90%E9%AB%98%E9%9F%B3%E8%B3%AA%E3%80%91%E4%BE%B5%E7%95%A5%21%E3%82%A4%E3%82%AB%E5%A8%98OP+%E3%80%8C%E4%BE%B5%E7%95%A5%E3%83%8E%E3%82%B9%E3%82%B9%E3%83%A1%E2%98%86%E3%80%8D%E7%94%BB%E5%83%8FVer.&status=ok';
    my $content = do {
        open my $fh, '<', 't/01_data.txt' or die $!;
        local $/;
        <$fh>;
    };

    my $contents = [$info, $content];

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
    video_id      => $video_id,
    fmt_lsit      => [ '22', '35', '34', '18', '5' ],
    suffix        => '.mp4',
    title         => '【高音質】侵略!イカ娘OP 「侵略ノススメ☆」画像Ver.',
    fmt           => '22',
    video_url     => 'http://v5.lscache8.c.youtube.com/videoplayback?ip=119.0.0.0&sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Cratebypass&fexp=906322%2C907048&itag=22&ipbits=8&sver=3&ratebypass=yes&expire=1292364000&key=yt1&signature=188170E1FAC8B18D7E88B133DC49C02AD6187825.84C91F49CF2E39ED76849BCF0741F228AA623551&id=472e91ba99b792a3',
    video_url_map => {
        22 => {
            suffix     => '.mp4',
            url        => 'http://v5.lscache8.c.youtube.com/videoplayback?ip=119.0.0.0&sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Cratebypass&fexp=906322%2C907048&itag=22&ipbits=8&sver=3&ratebypass=yes&expire=1292364000&key=yt1&signature=188170E1FAC8B18D7E88B133DC49C02AD6187825.84C91F49CF2E39ED76849BCF0741F228AA623551&id=472e91ba99b792a3',
            resolution => '1280x720',
            fmt        => '22'
        },
        35 => {
            suffix     => '.flv',
            url        => 'http://v20.lscache8.c.youtube.com/videoplayback?ip=119.0.0.0&sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor&fexp=906322%2C907048&algorithm=throttle-factor&itag=35&ipbits=8&burst=40&sver=3&expire=1292364000&key=yt1&signature=4F6ACD6242498CFCF188AE9DDAA7F017573A9EF1.7EBC6022BF96AB1341F172C4663ED34CAAD6F57C&factor=1.25&id=472e91ba99b792a3',
            resolution => '854x480',
            fmt        => '35'
        },
        34 => {
            suffix     => '.flv',
            url        => 'http://v10.lscache2.c.youtube.com/videoplayback?ip=119.0.0.0&sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor&fexp=906322%2C907048&algorithm=throttle-factor&itag=34&ipbits=8&burst=40&sver=3&expire=1292364000&key=yt1&signature=0552BEC0316BF3FB088F55C6B0BEF318CE0A7E3F.6844CB6F5E0B9CA10520F870B40E34EC39BDA1DB&factor=1.25&id=472e91ba99b792a3',
            resolution => '640x360',
            fmt        => '34'
        },
        18 => {
            suffix     => '.mp4',
            url        => 'http://v3.lscache3.c.youtube.com/videoplayback?ip=119.0.0.0&sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor&fexp=906322%2C907048&algorithm=throttle-factor&itag=18&ipbits=8&burst=40&sver=3&expire=1292364000&key=yt1&signature=B43BDC27CD9A3DA0BA665E58F9F070D5A1391E08.550D5AEACF834E86E9BB88566EF523FC671B9B84&factor=1.25&id=472e91ba99b792a3',
            resolution => '640x360',
            fmt        => '18'
        },
        5 => {
            suffix     => '.flv',
            url        => 'http://v3.lscache1.c.youtube.com/videoplayback?ip=119.0.0.0&sparams=id%2Cexpire%2Cip%2Cipbits%2Citag%2Calgorithm%2Cburst%2Cfactor&fexp=906322%2C907048&algorithm=throttle-factor&itag=5&ipbits=8&burst=40&sver=3&expire=1292364000&key=yt1&signature=328896AB78A29120F0015EC678BD7A5C5B710B98.4F3095A933ED887375887DBA4722C259CC724A31&factor=1.25&id=472e91ba99b792a3',
            resolution => '320x240',
            fmt        => '5'
        },
    },
};

done_testing;

__END__
