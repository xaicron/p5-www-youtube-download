use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;
use LWP::UserAgent;
use HTTP::Request;

plan skip_all => 'env P5_YOUTUBE_NETWORK_TESTS not set'
    unless defined($ENV{'P5_YOUTUBE_NETWORK_TESTS'});

sub check_video_fetch_url {
    my $video_id = shift;

    my $yt = WWW::YouTube::Download->new();
    my $url = $yt->playback_url($video_id);

    my $ua = LWP::UserAgent->new();
    $ua->agent('');
    $ua->timeout('60');
    $ua->env_proxy;

    my $request = HTTP::Request->new;
    $request->method('HEAD');
    $request->uri($url);

    my $response = $ua->request($request);
    my $code = $response->code;

    is $code, 200;
}

# random free video
check_video_fetch_url('Kdgt1ZHkvnM');

# vevo
check_video_fetch_url('cmSbXsFE3l8');

done_testing;
