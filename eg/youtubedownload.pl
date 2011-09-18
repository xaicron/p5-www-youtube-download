#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use WWW::YouTube::Download;
use LWP::UserAgent;

@ARGV || die "Usage: $0 [video_id, video_url or url to find video urls at] ...\n";

my $ua = LWP::UserAgent->new;

my @video_ids = map {
    if (/^(\w{11})$/ || /watch\?v=(\w{11})/) {
        $1
    }
    else {
        my $videos_at_url;
        if (/^(PL\w+)$/) {
            $videos_at_url = "http://www.youtube.com/playlist?list="
                . $1 .
                "&feature=mh_lolz"; # what the hell?
        }
        else {
            $videos_at_url = $_
        }
        my $response = $ua->get($videos_at_url);
        unless ($response->is_success) {
            die $response->status_line;
        }
        my @video_ids = $response->decoded_content =~
            /<a href="\/watch\?v=(\w{11})/g;
        @video_ids > 0 || die "no video urls found on $videos_at_url";
        my %video_ids = map { $_ => 1 } @video_ids;
        keys %video_ids;
    }
} @ARGV;



my $client = WWW::YouTube::Download->new(ua => $ua);
print "Going to download ".@video_ids." videos...\n";
for (@video_ids) {
    print "Downloading $_\n";
    $client->download($_, {save_as_title => 1});
    sleep int(15 * rand());
}
