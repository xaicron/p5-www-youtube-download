use strict;
use warnings;
use WWW::YouTube::Download;

my $video_id = shift || die "Usage: $0 [video_id|video_url]";

my $client = WWW::YouTube::Download->new;
$client->download($video_id, { cb => \&cb, fmt => 18 });

my $fh;
sub cb {
    my ($data, $res, $proto) = @_;
    
    unless ($fh) {
        open $fh, '>', "$video_id.mp4" or die "$video_id.mp4", " $!";
        binmode $fh;
    }
    
    print $fh $data;
}
