use strict;
use warnings;
use Test::More;
use Test::Requires 'Test::Script::Shebang';
use File::Find qw/find/;

my @files;
for my $dir (qw/bin script/) {
    next unless -d $dir;
    find {
        no_chdir => 1,
        wanted   => sub { push @files, $_ if -f },
    }, $dir;
}
plan skip_all => 'script not found' unless @files;

check_shebang(@files);

done_testing;
