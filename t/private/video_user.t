use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

my $wyd = WWW::YouTube::Download->new;

sub test_video_user {
    my ($content, $expects) = @_;
    my $user = $wyd->_fetch_user($content);
    is $user, $expects;
}

test_video_user(
    '<span class="yt-user-name " dir="ltr">GoogleTechTalks</span>',
    'GoogleTechTalks',
);

done_testing;
