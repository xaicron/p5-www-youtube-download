use strict;
use warnings;
use WWW::YouTube::Download;

my $url = shift || 'http://www.youtube.com/watch?v=w1IJiAXjj7k';

my $client       = WWW::YouTube::Download->new();
my $data         = $client->prepare_download($url);
my $umap         = $data->{video_url_map};
my @alternatives = @{$umap}{sort { $a <=> $b } keys %$umap};

$|++;
my $choice;
while (!defined $choice) {
   print {*STDOUT} "Available choices:\n";
   for my $alt (@alternatives) {
      printf {*STDOUT} "%3d - %4s - resolution %s\n",
        @{$alt}{qw< fmt suffix resolution >};
   }
   print {*STDOUT} "Your choice: ";
   (my $input = <STDIN>) =~ s/\s+//gmxs;
   if (($input =~ m{^(?: 0 | [1-9]\d*)$}mxs) && exists $umap->{$input}) {
      $choice = $input;
   }
   else {
      print {*STDOUT} "Invalid choice\n\n";
   }
} ## end while (!defined $choice)

# Ready to download
my $filename = "$data->{video_id}.$umap->{$choice}{suffix}";
$client->download($url, {fmt => $choice, filename => $filename});
print "saved '$filename'\n";
