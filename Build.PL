use strict;
use warnings FATAL => 'all';
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => { 'Test::More' => '0.98' },
    configure_requires   => { 'Module::Build' => '0.38' },
    requires             => {
        'XML::TreePP'     => '0',
        'URI'             => '0',
        'Term::ANSIColor' => '0',
        'URI::QueryParam' => '0',
        'perl'            => '5.008001',
        'LWP::UserAgent'  => '0',
        'HTML::Entities'  => '0',
        'JSON'            => '0'
    },
    no_index    => { 'directory' => [ 'inc', 't', 'xt' ] },
    name        => 'WWW-YouTube-Download',
    module_name => 'WWW::YouTube::Download',

    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',

    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
