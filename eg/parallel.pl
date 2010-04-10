use strict;
use warnings;
use WWW::YouTube::Download;
use Parallel::ForkManager;

my $urls = [qw{
    http://www.youtube.com/watch?v=kKVYVj5-wQ0
    http://www.youtube.com/watch?v=gtezI4QriS0
    http://www.youtube.com/watch?v=rTJbGp8og7g
}];

my $pm = Parallel::ForkManager->new(scalar @$urls);
for my $url (@$urls) {
    my $pid = $pm->start and next;

    my $client = WWW::YouTube::Download->new;
    $client->download($url);

    $pm->finish;
}

$pm->wait_all_children;
