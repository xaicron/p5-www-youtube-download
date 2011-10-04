#!perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions :config bundling);
use WWW::YouTube::Download;
use Encode qw(find_encoding decode_utf8);
use Time::HiRes;
use Term::ANSIColor qw(colored);

my $encode    = 'utf8';
my $overwrite = 0;
my $verbose   = 1;
my $interval  = 1; # sec
GetOptions(
    'o|output=s'   => \my $output,
    'F|fmt=i',     => \my $fmt,
    'v|verbose!'   => \$verbose,
    'i|interval=i' => \$interval,
    'e|encode=s'   => \$encode,
    'f|force!'     => \$overwrite,
    'q|quiet!'     => sub { $verbose = 0 },
    'h|help!'      => \&help,
    'V|version!'   => \&show_version,
) or help();
challeng_load_argv_from_fh() unless @ARGV;
help() unless @ARGV;

my $encoder = find_encoding($encode) or throw("not supported encoding: $encode");
$output = $encoder->decode($output) if $output;

my $client = WWW::YouTube::Download->new;

main: {
    while (@ARGV) {
        my $video_id = shift @ARGV;

        my $meta_data = $client->prepare_download($video_id);
        chatty("--> Working on $meta_data->{video_id}");
        if ($fmt && !$client->_is_supported_fmt($video_id, $fmt)) {
            throw("[$meta_data->{video_id}] this video has not supported fmt: $fmt");
        }

        $output = $client->_foramt_file_name($output, {
            video_id => $meta_data->{video_id},
            title    => decode_utf8($meta_data->{title}),
            fmt      => $fmt || $meta_data->{fmt},
            suffix   => $client->_suffix($fmt),
        });
        $output = $encoder->encode($output, sub { sprintf 'U+%x', shift });

        eval {
            $client->download($video_id, {
                file_name => $output,
                fmt       => $fmt,
                verbose   => $verbose,
                overwrite => $overwrite,
            });
        };
        throw("[$meta_data->{video_id}] $@") if $@;
        chatty(colored(['green'], 'Successfully download - '), $video_id);

        Time::HiRes::sleep($interval) if @ARGV;
    }
}

exit;

sub challeng_load_argv_from_fh {
    return unless $0 ne '-' && !-t STDIN;

    # e.g. $ youtube-dl.pl < video_list
    while (defined (my $line = <STDIN>)) {
        chomp $line;
        $line =~ s/#.*$//;       # comment
        $line =~ s/^\s+|\s+$//g; # trim spaces
        push @ARGV, $line;
    }
}

sub throw {
    die colored(['red'], 'ERROR: ', @_), "\n";
}

sub chatty {
    print @_, "\n";
}

sub show_version {
    print "youtube-dl.pl (WWW::YouTube::Download) version $WWW::YouTube::Download::VERSION\n";
    exit;
}

sub help {
    print << 'HELP';
Usage:
    youtube-dl.pl [options] video_id_or_video_url ...

Options:
    -h, --help          Show this message
    -o, --output        Output filename, supports `{$value}` style
    -e, --encode        File system encoding (e.g. cp932)
    -F, --fmt           Video quality (SEE ALSO wikipedia)
    -v, --verbose       Chatty output (defult enable)
    -f, --force         Force overwrite output file
    -q, --quiet         Silence
    -i, --interval      Download interval 

`{$value}` following are:
    {video_id}, {title}, {fmt}, {suffix}

    Example:
        $ youtube-dl.pl -o "[{video_id}] {title}.{suffix}"

HELP
    exit 1;
}

__END__
