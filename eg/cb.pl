use strict;
use warnings;
use WWW::YouTube::Download;

my $video_id = shift || die "Usage: $0 [video_id|video_url]";

my $client = WWW::YouTube::Download->new(encode => 'cp932');
$client->download($video_id, \&cb);

my $fh;
sub cb {
	my ($data, $res, $proto) = @_;
	
	unless ($fh) {
		open $fh, '>', $client->filename or die $client->filename, " $!";
		binmode $fh;
	}
	
	print $fh $data;
}
