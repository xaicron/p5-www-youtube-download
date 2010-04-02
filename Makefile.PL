use inc::Module::Install;
name 'WWW-YouTube-Download';
all_from 'lib/WWW/YouTube/Download.pm';

requires 'LWP';
requires 'URI::Escape';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
auto_include;
WriteAll;
