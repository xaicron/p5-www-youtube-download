use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_user_id {
    my ($input, $expects) = @_;
    is +WWW::YouTube::Download->new()->user_id($input), $expects;
}

test_user_id(
    'http://www.youtube.com/user/EpicStepsFromHell/videos?flow=list&view=0',
    'EpicStepsFromHell'
);

test_user_id(
    'http://www.youtube.com/user/ZackHemsey',
    'ZackHemsey'
);

test_user_id(
    'http://www.youtube.com/user/bsdconferences/',
    'bsdconferences'
);

test_user_id(
    'VEVO',
    'VEVO'
);

done_testing;
