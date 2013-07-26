use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_playlist_id {
    my ($input, $expects) = @_;
    is +WWW::YouTube::Download->new()->playlist_id($input), $expects;
}

test_playlist_id(
    'http://www.youtube.com/playlist?list=FLa6SM4ycX9Ltbrhf71es_RA',
    'FLa6SM4ycX9Ltbrhf71es_RA'
);

test_playlist_id(
    'FLbKM5fcSsaEFZRP-bjH8Y9w',
    'FLbKM5fcSsaEFZRP-bjH8Y9w'
);

test_playlist_id(
    'http://www.youtube.com/watch?v=9VV8sgVSZNQ&list=ALHTd1VmZQRNpEtPhKH9FrcB_S6domiCtv',
    'ALHTd1VmZQRNpEtPhKH9FrcB_S6domiCtv'
);

test_playlist_id(
    'http://www.youtube.com/playlist?list=PLUyiyCkoNwG8C_4ljTZWYYxmw7emk0W-f',
    'PLUyiyCkoNwG8C_4ljTZWYYxmw7emk0W-f'
);

test_playlist_id(
    'http://www.youtube.com/watch?v=tAjFnJuk1Aw&list=PL48DBEDD2147DDC46',
    'PL48DBEDD2147DDC46'
);

test_playlist_id(
    'ALHTd1VmZQRNpEtPhKH9FrcB_S6domiCtv',
    'ALHTd1VmZQRNpEtPhKH9FrcB_S6domiCtv'
);

test_playlist_id(
    'PLu-EVkxXzIVQp07QyLO0qFNQjBHkHwPf2',
    'PLu-EVkxXzIVQp07QyLO0qFNQjBHkHwPf2'
);

test_playlist_id(
    '3J3dCCJTos-sucVYP7nAWmR97LFbiVNJ',
    '3J3dCCJTos-sucVYP7nAWmR97LFbiVNJ'
);

test_playlist_id(
    'PLA0FA2050A02AEFF4',
    'PLA0FA2050A02AEFF4'
);

test_playlist_id(
    'C5353E661DEF8150',
    'C5353E661DEF8150'
);

done_testing;
