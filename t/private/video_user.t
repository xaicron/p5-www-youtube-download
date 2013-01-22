use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_video_user {
    my ($input, $expects) = @_;
    is +WWW::YouTube::Download::_video_user($input), $expects;
}

test_video_id(
    'http://www.youtube.com/watch?v=1sV8Z_Lmpt4',
    'GoogleTechTalks',
);

test_video_id(
    'http://www.youtube.com/watch?v=o3hu3iG8B2g',
    'Real454545',
);

test_video_id(
    'http://www.youtube.com/watch?v=Wa3qBsHfZjI',
    'ytoytoyto',  # fails? as display name and username (in url) is different
);

test_video_id(
    'http://www.youtube.com/watch?v=gAWiXbT599E',
    'azamsharp',
);


done_testing;
