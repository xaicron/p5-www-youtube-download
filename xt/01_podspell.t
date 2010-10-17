use strict;
use warnings;
use Test::More;
use Test::Requires 'Test::Spelling';
use Config;
use File::Spec;
use ExtUtils::MakeMaker;

my %cmd_map = (
    spell  => 'spell',
    aspell => 'aspell list',
    ispell => 'ispell -l',
);

my $spell_cmd;
for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
    next if $dir eq '';
    ($spell_cmd) = map { $cmd_map{$_} } grep {
        my $abs = File::Spec->catfile($dir, $_);
        -x $abs or MM->maybe_command($abs);
    } keys %cmd_map;
    last if $spell_cmd;
}
$spell_cmd = $ENV{SPELL_CMD} if $ENV{SPELL_CMD};
plan skip_all => "spell command are not available." unless $spell_cmd;
add_stopwords(map { split /[\s\:\-]/ } <DATA>);
set_spell_cmd($spell_cmd);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');
__DATA__
Yuji Shimada
xaicron {at} gmail.com
WWW::YouTube::Download
yusukebe:
url
simply
