#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use warnings;
use WWW::YouTube::Download;
use LWP::UserAgent;

if ($ARGV[0] && $ARGV[0] eq "--strip-audio") {
    # bonus functionality!
    die "need ffmpeg" unless -x "/usr/bin/ffmpeg";
    die "need MP4box, from 'gpac'" unless -x "/usr/bin/MP4Box";
    my @flvs = map { chomp; $_ } `ls -1 *.flv`;
    exit unless @flvs;
    print "Going to copy audio tracks out of ".@flvs." flvs...\n";
    my $wd = `pwd`; chomp $wd;
    for my $flv (@flvs) {
        print "Processing '$flv'\n";
        my $tmp = "/tmp/$$.hax";
        system 'ln', '-s', "$wd/$flv", $tmp;
        my $pid = $$;
        `ffmpeg -i $tmp -acodec copy finished.$pid.aac`;
        `MP4Box -new -add finished.$pid.aac finished.$pid.mp4`;
        `rm finished.$pid.aac`;
        my $finito = $flv;
        $finito =~ s/flv$/mp4/;
        system("mv", "finished.$pid.mp4", $finito);
        system('unlink', $tmp);
    }
    print "\n\nDone. Check things over and remove the .flv sources yourself.\n";
    exit;
}

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
my $skipto = undef; # "wCCNGTW8eH8";
for (@video_ids) {
    next unless !$skipto || (/$skipto/ && do { undef $skipto; 1 });
    print "Downloading $_\n";
    eval { $client->download($_, {save_as_title => 1}); };
    if ($@) {
        warn "$@\n";
        warn "Enter to continue... Resume? See code a few line up\n";
        <STDIN>
    }
    else {
        sleep int(15 * rand());
    }
}
