use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_video_id {
    my ($input, $expects) = @_;
    is +WWW::YouTube::Download::_video_id($input), $expects;
}

test_video_id(
    'http://www.youtube.com/watch?feature=player_detailpage&v=jDJg0cnvBFM',
    'jDJg0cnvBFM',
);

test_video_id(
    'http://www.youtube.com/watch?v=_cqgWvFmtz0',
    '_cqgWvFmtz0',
);

test_video_id(
    'http://www.youtube.com/watch?v=ooZPKEAaidY&feature=player_profilepage',
    'ooZPKEAaidY',
);

test_video_id(
    'http://www.youtube.com/watch?v=ooZPKEAaidY&feature=player_profilepage#t=191s',
    'ooZPKEAaidY',
);

test_video_id(
    'http://www.youtube.com/watch?v=jDJg0cnvBFM&feature=related',
    'jDJg0cnvBFM',
);

test_video_id(
    'http://www.youtube.com/v/rQ4qoX7GWME',
    'rQ4qoX7GWME',
);

test_video_id(
    'JZcrLTSKHlU',
    'JZcrLTSKHlU',
);

test_video_id(
    '38O4rHD_PQs',
    '38O4rHD_PQs',
);

test_video_id(
    'http://www.youtube.com/user/Supercali006#p/u/40/ZgDKIyxaK8A',
    'ZgDKIyxaK8A',
);

done_testing;

