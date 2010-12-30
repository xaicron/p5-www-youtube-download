use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_video_id {
    my ($input, $expect) = @_;
    is +WWW::YouTube::Download::_video_id($input), $expect;
}

test_video_id('http://www.youtube.com/watch?v=PWzcD2UlglU', 'PWzcD2UlglU');
test_video_id('PWzcD2UlglU', 'PWzcD2UlglU');

# $1 problem 
'foo' =~ /(foo)/;
test_video_id('PWzcD2UlglU', 'PWzcD2UlglU');

done_testing;
