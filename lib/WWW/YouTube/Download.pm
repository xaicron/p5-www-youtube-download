package WWW::YouTube::Download;

use strict;
use warnings;
use 5.008001;

our $VERSION = '0.56';

use Carp qw(croak);
use URI ();
use LWP::UserAgent;
use JSON;
use HTML::Entities qw/decode_entities/;
use HTTP::Request;

$Carp::Internal{ (__PACKAGE__) }++;

use constant DEFAULT_FMT => 18;

my $base_url = 'http://www.youtube.com/watch?v=';

sub new {
    my $class = shift;
    my %args = @_;
    $args{ua} = LWP::UserAgent->new(
        agent      => __PACKAGE__.'/'.$VERSION,
        parse_head => 0,
    ) unless exists $args{ua};
    bless \%args, $class;
}

for my $name (qw[video_id video_url title user fmt fmt_list suffix]) {
    no strict 'refs';
    *{"get_$name"} = sub {
        use strict 'refs';
        my ($self, $video_id) = @_;
        croak "Usage: $self->get_$name(\$video_id|\$watch_url)" unless $video_id;
        my $data = $self->prepare_download($video_id);
        return $data->{$name};
    };
}

sub playback_url {
    my ($self, $video_id, $args) = @_;
    croak "Usage: $self->playback_url('[video_id|video_url]')" unless $video_id;
    $args ||= {};

    my $data = $self->prepare_download($video_id);
    my $fmt  = $args->{fmt} || $data->{fmt} || DEFAULT_FMT;
    my $video_url = $data->{video_url_map}{$fmt}{url} || croak "this video does not offer format (fmt) $fmt";

    return $video_url;
}

sub download {
    my ($self, $video_id, $args) = @_;
    croak "Usage: $self->download('[video_id|video_url]')" unless $video_id;
    $args ||= {};

    my $data = $self->prepare_download($video_id);

    my $fmt = $args->{fmt} || $data->{fmt} || DEFAULT_FMT;

    my $video_url = $data->{video_url_map}{$fmt}{url} || croak "this video has not supported fmt: $fmt";
    $args->{filename} ||= $args->{file_name};
    my $filename = $self->_format_filename($args->{filename}, {
        video_id   => $data->{video_id},
        title      => $data->{title},
        user       => $data->{user},
        fmt        => $fmt,
        suffix     => $data->{video_url_map}{$fmt}{suffix} || _suffix($fmt),
        resolution => $data->{video_url_map}{$fmt}{resolution} || '0x0',
    });

    $args->{cb} = $self->_default_cb({
        filename  => $filename,
        verbose   => $args->{verbose},
        overwrite => defined $args->{overwrite} ? $args->{overwrite} : 1,
    }) unless ref $args->{cb} eq 'CODE';

    my $res = $self->ua->get($video_url, ':content_cb' => $args->{cb});
    croak "!! $video_id download failed: ", $res->status_line if $res->is_error;
}

sub _format_filename {
    my ($self, $filename, $data) = @_;
    return "$data->{video_id}.$data->{suffix}" unless defined $filename;
    $filename =~ s#{([^}]+)}#$data->{$1} || "{$1}"#eg;
    return $filename;
}

sub _is_supported_fmt {
    my ($self, $video_id, $fmt) = @_;
    my $data = $self->prepare_download($video_id);
    $data->{video_url_map}{$fmt}{url} ? 1 : 0;
}

sub _default_cb {
    my ($self, $args) = @_;
    my ($file, $verbose, $overwrite) = @$args{qw/filename verbose overwrite/};

    croak "file exists! $file" if -f $file and !$overwrite;
    open my $wfh, '>', $file or croak $file, " $!";
    binmode $wfh;

    print "Downloading `$file`\n" if $verbose;
    return sub {
        my ($chunk, $res, $proto) = @_;
        print $wfh $chunk; # write file

        if ($verbose || $self->{verbose}) {
            my $size = tell $wfh;
            my $total = $res->header('Content-Length');
            printf "%d/%d (%.2f%%)\r", $size, $total, $size / $total * 100;
            print "\n" if $total == $size;
        }
    };
}

sub prepare_download {
    my ($self, $video_id) = @_;
    croak "Usage: $self->prepare_download('[video_id|watch_url]')" unless $video_id;
    $video_id = $self->video_id($video_id);

    return $self->{cache}{$video_id} if ref $self->{cache}{$video_id} eq 'HASH';

    my $content       = $self->_get_content($video_id);
    my $title         = $self->_fetch_title($content);
    my $user          = $self->_fetch_user($content);
    my $video_url_map = $self->_fetch_video_url_map($content);

    my $fmt_list = [];
    my $sorted = [
        map {
            push @$fmt_list, $_->[0]->{fmt};
            $_->[0]
        } sort {
            $b->[1] <=> $a->[1]
        } map {
            my $resolution = $_->{resolution};
            $resolution =~ s/(\d+)x(\d+)/$1 * $2/e;
            [ $_, $resolution ]
        } values %$video_url_map,
    ];

    my $hq_data = $sorted->[0];

    return $self->{cache}{$video_id} = {
        video_id      => $video_id,
        video_url     => $hq_data->{url},
        title         => $title,
        user          => $user,
        video_url_map => $video_url_map,
        fmt           => $hq_data->{fmt},
        fmt_list      => $fmt_list,
        suffix        => $hq_data->{suffix},
        resolution    => $hq_data->{resolution},
    };
}

sub _fetch_title {
    my ($self, $content) = @_;

    my ($title) = $content =~ /<meta name="title" content="(.+?)">/ or return;
    return decode_entities($title);
}

sub _fetch_user {
    my ($self, $content) = @_;

	if( $content =~ /<span class="yt-user-name [^>]+>([^<]+)<\/span>/ ){
		return decode_entities($1);
	}else{
		return;
	}	
}

sub _fetch_video_url_map {
    my ($self, $content) = @_;

    my $args = $self->_get_args($content);
    unless ($args->{fmt_list} and $args->{url_encoded_fmt_stream_map}) {
        croak 'failed to find video urls';
    }

    my $fmt_map     = _parse_fmt_map($args->{fmt_list});
    my $fmt_url_map = _parse_stream_map($args->{url_encoded_fmt_stream_map});

    my $video_url_map = +{
        map {
            $_->{fmt} => $_,
        } map +{
            fmt        => $_,
            resolution => $fmt_map->{$_},
            url        => $fmt_url_map->{$_},
            suffix     => _suffix($_),
        }, keys %$fmt_map
    };

    return $video_url_map;
}

sub _get_content {
    my ($self, $video_id) = @_;

    my $url = "$base_url$video_id";

    my $req = HTTP::Request->new;
    $req->method('GET');
    $req->uri($url);
    $req->header('Accept-Language' => 'en-US');

    my $res = $self->ua->request($req);
    croak "GET $url failed. status: ", $res->status_line if $res->is_error;

    return $res->content;
}

sub _get_args {
    my ($self, $content) = @_;

    my $data;
    for my $line (split "\n", $content) {
        next unless $line;
        if ($line =~ /the uploader has not made this video available in your country/i) {
            croak 'Video not available in your country';
        }
        elsif ($line =~ /^.+ytplayer\.config\s*=\s*({.*})/) {
            $data = JSON->new->utf8(1)->decode($1);
            last;
        }
    }

    croak 'failed to extract JSON data' unless $data->{args};

    return $data->{args};
}

sub _parse_fmt_map {
    my $param = shift;
    my $fmt_map = {};
    for my $stuff (split ',', $param) {
        my ($fmt, $resolution) = split '/', $stuff;
        $fmt_map->{$fmt} = $resolution;
    }

    return $fmt_map;
}

sub _sigdecode {
    my @s = @_;

    # based on youtube_dl/extractor/youtube.py from yt-dl.org
    if (@s == 92) {
	return ($s[25], @s[3..24], $s[0], @s[26..41], $s[79], @s[43..78], $s[91], @s[80..82]);
    } elsif (@s == 90) {
	return ($s[25], @s[3..24], $s[2], @s[26..39], $s[77], @s[41..76], $s[89], @s[78..80]);
    } elsif (@s == 88) {
        return ($s[48], reverse(@s[68..81]), $s[82], reverse(@s[63..66]), $s[85],
                reverse(@s[49..61]), $s[67], reverse(@s[13..47]), $s[3],
                reverse(@s[4..11]), $s[2], $s[12]);
    } elsif (@s == 87) {
        return (@s[4..22], $s[86], @s[24..84]);
    } elsif (@s == 86) {
        return (@s[2..62], $s[82], @s[64..81], $s[63]);
    } elsif (@s == 85) {
       return (@s[2..7], $s[0], @s[9..20], $s[65], @s[22..64], $s[84], @s[66..81], $s[21]);
    } elsif (@s == 84) {
        return (reverse(@s[37..83]), $s[2], reverse(@s[27..35]), $s[3],
                reverse(@s[4..25]), $s[26]);
    } elsif (@s == 83) {
        return ($s[6], @s[3..5], $s[33], @s[7..23], $s[0], @s[25..32], $s[53], @s[34..52], $s[24], @s[54..82]);
    } elsif (@s == 82) {
        return ($s[36], reverse(@s[68..79]), $s[81], reverse(@s[41..66]), $s[33],
                reverse(@s[37..39]), $s[40], $s[35], $s[0], $s[67],
                reverse(@s[1..32]), $s[34]);
    } elsif (@s == 81) {
        return ($s[56], reverse(@s[57..79]), $s[41], reverse(@s[42..55]), $s[80],
		reverse(@s[35..40]), $s[0], reverse(@s[30..33]), $s[34],
		reverse(@s[10..28]), $s[29], reverse(@s[1..8]), $s[9]);
    } elsif (@s == 79) {
        return ($s[54], reverse(@s[55..77]), $s[39], reverse(@s[40..53]), $s[78],
		reverse(@s[35..38]), $s[0], reverse(@s[30..33]), $s[34],
		reverse(@s[10..28]), $s[29], reverse(@s[1..8]), $s[9]);
    }

    return ();    # fail
}

sub _getsig {
    my $sig = shift;
    croak 'Unable to find signature' unless $sig;
    my @sig = _sigdecode(split(//, $sig));
    croak "Unable to decode signature $sig of length " . length($sig) unless @sig;
    return join('', @sig);
}

sub _parse_stream_map {
    my $param       = shift;
    my $fmt_url_map = {};
    for my $stuff (split ',', $param) {
        my $uri = URI->new;
        $uri->query($stuff);
        my $query = +{ $uri->query_form };
        my $sig = $query->{sig} || _getsig($query->{s});
        my $url = $query->{url};
        $fmt_url_map->{$query->{itag}} = $url.'&signature='.$sig;
    }

    return $fmt_url_map;
}

sub ua {
    my ($self, $ua) = @_;
    return $self->{ua} unless $ua;
    croak "Usage: $self->ua(\$LWP_LIKE_OBJECT)" unless eval { $ua->isa('LWP::UserAgent') };
    $self->{ua} = $ua;
}

sub _suffix {
    my $fmt = shift;
    return $fmt =~ /43|44|45/    ? 'webm'
         : $fmt =~ /18|22|37|38/ ? 'mp4'
         : $fmt =~ /13|17/       ? '3gp'
         :                         'flv'
    ;
}

sub video_id {
    my ($self, $stuff) = @_;
    return unless $stuff;
    if ($stuff =~ m{/.*?[?&;!](?:v|video_id)=([^&#?=/;]+)}) {
        return $1;
    }
    elsif ($stuff =~ m{/(?:e|v|embed)/([^&#?=/;]+)}) {
        return $1;
    }
    elsif ($stuff =~ m{#p/(?:u|search)/\d+/([^&?/]+)}) {
        return $1;
    }
    elsif ($stuff =~ m{youtu.be/([^&#?=/;]+)}) {
        return $1;
    }
    else {
        return $stuff;
    }
}

sub playlist_id {
    my ($self, $stuff) = @_;
    return unless $stuff;
    if ($stuff =~ m{/.*?[?&;!]list=([^&#?=/;]+)}) {
        return $1;
    }
    elsif ($stuff =~ m{^\s*([FP]L[\w\-]+)\s*$}) {
        return $1;
    }
    return $stuff;
}

sub user_id {
    my ($self, $stuff) = @_;
    return unless $stuff;
    if ($stuff =~ m{/user/([^&#?=/;]+)}) {
        return $1;
    }
    return $stuff;
}

1;
__END__

=head1 NAME

WWW::YouTube::Download - Very simple YouTube video download interface

=head1 SYNOPSIS

  use WWW::YouTube::Download;

  my $client = WWW::YouTube::Download->new;
  $client->download($video_id);

  my $video_url = $client->get_video_url($video_id);
  my $title     = $client->get_title($video_id);     # maybe encoded utf8 string.
  my $fmt       = $client->get_fmt($video_id);       # maybe highest quality.
  my $suffix    = $client->get_suffix($video_id);    # maybe highest quality file suffix

=head1 DESCRIPTION

WWW::YouTube::Download is a download video from YouTube.

=head1 METHODS

=over

=item B<new()>

  $client = WWW::YouTube::Download->new;

Creates a WWW::YouTube::Download instance.

=item B<download($video_id [, \%args])>

  $client->download($video_id);
  $client->download($video_id, {
      fmt      => 37,
      filename => 'sample.mp4', # save file name
  });
  $client->download($video_id, {
      filename => '{title}.{suffix}', # maybe `video_title.mp4`
  });
  $client->download($video_id, {
      cb => \&callback,
  });

Download the video file.
The first parameter is passed to YouTube video url.

Allowed arguments:

=over

=item C<cb>

Set a callback subroutine, SEE L<LWP::UserAgent> ':content_cb'
for details.

=item C<filename>

Set the filename, possibly using placeholders to be filled with
information gathered about the video.

C<< filename >> supported format placeholders:

  {video_id}
  {title}
  {user}
  {fmt}
  {suffix}
  {resolution}

Output filename is set to C<{video_id}.{suffix}> by default.

=item C<file_name>

B<< DEPRECATED >> alternative for C<filename>.

=item C<fmt>

set the format to download. Defaults to the best video quality
(inferred by the available resolutions).

=back


=item B<playback_url($video_id, [, \%args])>

  $client->playback_url($video_id);
  $client->playback_url($video_id, { fmt => 37 });

Return playback URL of the video. This is direct link to the movie file.
Function supports only "fmt" option.

=item B<prepare_download($video_id)>

Gather data about the video. A hash reference is returned, with the following
keys:

=over

=item C<fmt>

the default, suggested format. It is inferred by selecting the
alternative with the highest resolution.

=item C<fmt_list>

the list of available formats, as an array reference.

=item C<suffix>

the filename extension associated to the default format (see C<fmt>
above).

=item C<title>

the title of the video

=item C<user>

the YouTube user owning the video

=item C<video_id>

the video identifier

=item C<video_url>

the URL of the video associated to the default format (see C<fmt>
above).

=item C<video_url_map>

an hash reference containing details about all available formats.

=back

The C<video_url_map> has one key/value pair for each available format,
where the key is the format identifier (can be used as C<fmt> parameter
for L</download>, for example) and the value is a hash reference with
the following data:

=over

=item C<fmt>

the format specifier, that can be passed to L</download>

=item C<resolution>

the resolution as I<width>xI<height>

=item C<suffix>

the suffix, providing a hint about the video format (e.g. webm, flv, ...)

=item C<url>

the URL where the video can be found

=back

=item B<ua([$ua])>

  $self->ua->agent();
  $self->ua($LWP_LIKE_OBJECT);

Sets and gets LWP::UserAgent object.

=item B<video_id($url)>

Parses given URL and returns video ID.

=item B<playlist_id($url)>

Parses given URL and returns playlist ID.

=item B<user_id($url)>

Parses given URL and returns YouTube username.

=item B<get_video_url($video_id)>

=item B<get_title($video_id)>

=item B<get_user($video_id)>

=item B<get_fmt($video_id)>

=item B<get_fmt_list($video_id)>

=item B<get_suffix($video_id)>

=back

=head1 AUTHOR

xaicron E<lt>xaicron {@} cpan.orgE<gt>

=head1 CONTRIBUTORS

yusukebe

=head1 BUG REPORTING

Plese use github issues: L<< https://github.com/xaicron/p5-www-youtube-download/issues >>.

=head1 SEE ALSO

L<WWW::NicoVideo::Download>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
