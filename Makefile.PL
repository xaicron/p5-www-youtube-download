use inc::Module::Install;
name 'WWW-YouTube-Download';
all_from 'lib/WWW/YouTube/Download.pm';

requires 'URI';
requires 'URI::QueryParam';
requires 'LWP::UserAgent';
requires 'JSON';
requires 'HTML::Entities';
requires 'XML::TreePP'; # for youtube-playlists.pl

tests 't/*.t t/*/*.t';
author_tests 'xt';

install_script 'bin/youtube-download.pl', 'bin/youtube-playlists.pl';

test_requires 'Test::More', '0.96';
auto_set_repository;
WriteAll;
