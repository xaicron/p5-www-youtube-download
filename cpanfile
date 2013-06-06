requires 'HTML::Entities';
requires 'JSON';
requires 'LWP::UserAgent';
requires 'Term::ANSIColor';
requires 'URI';
requires 'URI::QueryParam';
requires 'XML::TreePP';
requires 'perl', '5.008001';

on build => sub {
    requires 'Test::More', '0.98';
};
