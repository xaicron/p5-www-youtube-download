use inc::Module::Install;
name 'WWW-YouTube-Download';
all_from 'lib/WWW/YouTube/Download.pm';

requires 'URI';
requires 'URI::QueryParam';
requires 'LWP::UserAgent';
requires 'JSON';
requires 'HTML::Entities';
requires 'Term::ANSIColor'; # for youtube-download and youtube-playlists
requires 'XML::TreePP'; # for youtube-playlists

tests 't/*.t t/*/*.t';
author_tests 'xt';

install_script 'bin/youtube-download', 'bin/youtube-playlists';

test_requires 'Test::More', '0.96';
auto_set_repository;
WriteAll;
