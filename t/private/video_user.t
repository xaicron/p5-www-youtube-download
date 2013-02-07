use strict;
use warnings;
use Test::More tests => 4;
use WWW::YouTube::Download;

my $wyd = WWW::YouTube::Download->new();

sub test_video_user {
        my ($url, $expects) = @_;
        my $data = $wyd->prepare_download($url);
        is( $data->{user}, $expects);
}

test_video_user(
    'http://www.youtube.com/watch?v=1sV8Z_Lmpt4',
    'GoogleTechTalks',
);

test_video_user(
    'http://www.youtube.com/watch?v=o3hu3iG8B2g',
    'Real454545',
);

test_video_user(
    'http://www.youtube.com/watch?v=Wa3qBsHfZjI',
    'Tatsuo YAMASHITA',  # username is /user/ytoytoyto BUT displayed name is "Tatsuo YAMASHITA"
);

test_video_user(
    'http://www.youtube.com/watch?v=gAWiXbT599E',
    'azamsharp',
);


done_testing
