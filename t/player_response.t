use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;
use LWP::UserAgent;
use HTTP::Request;
use Mock::Quick;

my $control = qclass(
  -takeover => 'WWW::YouTube::Download',
  _get_content => sub {
    my $content;
    open my $fh, '<', 't/data/player_response.html';
    $content = do { local $/; <$fh> };
    return $content;
  }
);

my $yt = WWW::YouTube::Download->new();

is_deeply $yt->prepare_download('Y1I1KcKvz9Q'), {
  'fmt' => 'video/mp4; codecs="avc1.64001F, mp4a.40.2"',
  'fmt_list' => [
    'video/mp4; codecs="avc1.64001F, mp4a.40.2"',
    'video/mp4; codecs="avc1.42001E, mp4a.40.2"'
  ],
  'resolution' => '1280x720',
  'suffix' => 'mp4',
  'title' => "2016 -\x{200e}Perl's Worst Best Practices\x{200e} - Daina Pettit",
  'user' => 'Conference in the Cloud! A Perl and Raku Conf',
  'video_id' => 'Y1I1KcKvz9Q',
  'video_url' => 'https://r8---sn-uo1-fabe.googlevideo.com/videoplayback?expire=1591286259&ei=k8XYXrpTgbi-BOKUl8AC&ip=222.155.23.220&id=o-ACzVrS0ntoeNxkxf5Eyq0kh40yqw_H8JvAo6oomIF0vi&itag=22&source=youtube&requiressl=yes&mh=nM&mm=31%2C29&mn=sn-uo1-fabe%2Csn-ntqe6nes&ms=au%2Crdu&mv=m&mvi=7&pl=21&initcwndbps=1255000&vprv=1&mime=video%2Fmp4&ratebypass=yes&dur=2664.791&lmt=1471517080079780&mt=1591264536&fvip=5&c=WEB&sparams=expire%2Cei%2Cip%2Cid%2Citag%2Csource%2Crequiressl%2Cvprv%2Cmime%2Cratebypass%2Cdur%2Clmt&sig=AOq0QJ8wRQIhAKbSlz0qjINeYyhN1BhyEcEJk6uWrx4ZAqe-EQdr4AW0AiAL68CXNXGq39ov1k0UEbYTGiKb7J6xQCYT2Me7Zk3ZRA%3D%3D&lsparams=mh%2Cmm%2Cmn%2Cms%2Cmv%2Cmvi%2Cpl%2Cinitcwndbps&lsig=AG3C_xAwRAIgSfHsoUVS7LVwrzJNCrTEJI7T9Fmj3j6Mt8bDeFrdM0ECIB6Nvdhmdk3Y929DlGC9ILinX3CRms0pGkfCmeMmd_GB',
  'video_url_map' => {
    'video/mp4; codecs="avc1.42001E, mp4a.40.2"' => {
      'fmt' => 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
      'resolution' => '640x360',
      'suffix' => 'mp4',
      'url' => 'https://r8---sn-uo1-fabe.googlevideo.com/videoplayback?expire=1591286259&ei=k8XYXrpTgbi-BOKUl8AC&ip=222.155.23.220&id=o-ACzVrS0ntoeNxkxf5Eyq0kh40yqw_H8JvAo6oomIF0vi&itag=18&source=youtube&requiressl=yes&mh=nM&mm=31%2C29&mn=sn-uo1-fabe%2Csn-ntqe6nes&ms=au%2Crdu&mv=m&mvi=7&pl=21&initcwndbps=1255000&vprv=1&mime=video%2Fmp4&gir=yes&clen=110597265&ratebypass=yes&dur=2664.791&lmt=1466645029886574&mt=1591264536&fvip=5&c=WEB&sparams=expire%2Cei%2Cip%2Cid%2Citag%2Csource%2Crequiressl%2Cvprv%2Cmime%2Cgir%2Cclen%2Cratebypass%2Cdur%2Clmt&sig=AOq0QJ8wRgIhAMgkdpjZuGCkvPMUoJ4ks1z4ZXqQCj7M8fjogmEFCiP1AiEA1UbgDHQ-c13XOlLYmAR3OQ4J-KmAo8XuAeqsxsir2V8%3D&lsparams=mh%2Cmm%2Cmn%2Cms%2Cmv%2Cmvi%2Cpl%2Cinitcwndbps&lsig=AG3C_xAwRAIgSfHsoUVS7LVwrzJNCrTEJI7T9Fmj3j6Mt8bDeFrdM0ECIB6Nvdhmdk3Y929DlGC9ILinX3CRms0pGkfCmeMmd_GB'
    },
    'video/mp4; codecs="avc1.64001F, mp4a.40.2"' => {
      'fmt' => 'video/mp4; codecs="avc1.64001F, mp4a.40.2"',
      'resolution' => '1280x720',
      'suffix' => 'mp4',
      'url' => 'https://r8---sn-uo1-fabe.googlevideo.com/videoplayback?expire=1591286259&ei=k8XYXrpTgbi-BOKUl8AC&ip=222.155.23.220&id=o-ACzVrS0ntoeNxkxf5Eyq0kh40yqw_H8JvAo6oomIF0vi&itag=22&source=youtube&requiressl=yes&mh=nM&mm=31%2C29&mn=sn-uo1-fabe%2Csn-ntqe6nes&ms=au%2Crdu&mv=m&mvi=7&pl=21&initcwndbps=1255000&vprv=1&mime=video%2Fmp4&ratebypass=yes&dur=2664.791&lmt=1471517080079780&mt=1591264536&fvip=5&c=WEB&sparams=expire%2Cei%2Cip%2Cid%2Citag%2Csource%2Crequiressl%2Cvprv%2Cmime%2Cratebypass%2Cdur%2Clmt&sig=AOq0QJ8wRQIhAKbSlz0qjINeYyhN1BhyEcEJk6uWrx4ZAqe-EQdr4AW0AiAL68CXNXGq39ov1k0UEbYTGiKb7J6xQCYT2Me7Zk3ZRA%3D%3D&lsparams=mh%2Cmm%2Cmn%2Cms%2Cmv%2Cmvi%2Cpl%2Cinitcwndbps&lsig=AG3C_xAwRAIgSfHsoUVS7LVwrzJNCrTEJI7T9Fmj3j6Mt8bDeFrdM0ECIB6Nvdhmdk3Y929DlGC9ILinX3CRms0pGkfCmeMmd_GB'
    }
  }
}, 'correct data structure';

done_testing;

__DATA__
