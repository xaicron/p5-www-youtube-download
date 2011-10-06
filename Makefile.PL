use inc::Module::Install;
name 'WWW-YouTube-Download';
all_from 'lib/WWW/YouTube/Download.pm';

requires 'URI';
requires 'LWP::UserAgent';
requires 'JSON';
requires 'HTML::Entities';

tests 't/*.t t/*/*.t';
author_tests 'xt';

install_script 'bin/youtube-download.pl';

test_requires 'Test::More', '0.96';
auto_set_repository;
WriteAll;
