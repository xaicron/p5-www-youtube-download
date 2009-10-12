use inc::Module::Install;
name 'WWW-YouTube-Download';
all_from 'lib/WWW/YouTube/Download.pm';

requires 'JSON';
requires 'Web::Scraper';
requires 'Any::Moose';
requires 'URI::Escape';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
