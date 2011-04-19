package WWW::YouTube::Download;

use strict;
use warnings;
use 5.008001;

our $VERSION = '0.25';

use Carp ();
use URI ();
use LWP::UserAgent;
use URI::Escape qw/uri_unescape/;
use JSON;
use HTML::Entities qw/decode_entities/;

use constant DEFAULT_FMT => 18;

my $base_url = 'http://www.youtube.com/watch?v=';
my $info     = 'http://www.youtube.com/get_video_info?video_id=';

sub new {
    my $class = shift;
    my %args = @_;
    $args{ua} = LWP::UserAgent->new unless exists $args{ua};
    bless \%args, $class;
}

for my $name (qw[video_id video_url title fmt fmt_list suffix]) {
    no strict 'refs';
    *{"get_$name"} = sub {
        my $self = shift;
        my $video_id = shift || Carp::croak "Usage: $self->get_$name(\$video_id|\$watch_url)";

        my $data = $self->prepare_download($video_id);
        return $data->{$name};
    };
}

sub download {
    my $self = shift;
    my $video_id = shift || Carp::croak "Usage: $self->download('[video_id|video_url]')";
    my $args = shift || {};

    my $data = $self->prepare_download($video_id);

    my $fmt = $args->{fmt} || $data->{fmt} || DEFAULT_FMT;
    my $video_url = $data->{video_url_map}{$fmt}{url} || Carp::croak "this video has not supported fmt: $fmt";
    my $file_name = $args->{file_name} || $data->{video_id} . _suffix($fmt);

    $args->{cb} = $self->_default_cb({
        file_name => $file_name,
        verbose   => $args->{verbose},
    }) unless ref $args->{cb} eq 'CODE';

    my $res = $self->ua->get($video_url, ':content_cb' => $args->{cb});
    Carp::croak '!! $video_id download failed: ', $res->status_line if $res->is_error;
}

sub _default_cb {
    my $self = shift;
    my $args = shift;

    open my $wfh, '>', $args->{file_name} or die $args->{file_name}, " $!";
    binmode $wfh;
    return sub {
        my ($chunk, $res, $proto) = @_;
        print $wfh $chunk; # write file

        if ($self->{verbose} || $args->{verbose}) {
            my $size = tell $wfh;
            if (my $total = $res->header('Content-Length')) {
                printf "%d/%d (%f%%)\r", $size, $total, $size / $total * 100;
            }
            else {
                printf "%d/Unknown bytes\r", $size;
            }
        }
    };
}

sub prepare_download {
    my $self = shift;
    my $video_id = shift || Carp::croak "Usage: $self->prepare_download('[video_id|watch_url]')";
    $video_id = _video_id($video_id);

    return $self->{cache}{$video_id} if ref $self->{cache}{$video_id} eq 'HASH';

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    my $content       = $self->_get_content($video_id);
    my $title         = $self->_fetch_title($content);
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
        video_url_map => $video_url_map,
        fmt           => $hq_data->{fmt},
        fmt_lsit      => $fmt_list,
        suffix        => $hq_data->{suffix},
    };
}

sub _fetch_title {
    my ($self, $content) = @_;

    my ($title) = $content =~ m|<title>(.+)</title>|ims or return;
    $title =~ s/[\r\n]|^\s+|\s+$//g;
    $title = (split /\s+-\s+/, $title, 2)[1];
    return decode_entities($title);
}

sub _fetch_video_url_map {
    my ($self, $content) = @_;

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    my $args        = $self->_get_args($content);
    my $fmt_url_map = _parse_fmt_url_map($args->{fmt_url_map});
    my $fmt_map     = _parse_fmt_map($args->{fmt_map});

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

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    my $url = "$base_url$video_id";
    my $res = $self->ua->get($url);
    Carp::croak "GET $url failed. status: ", $res->status_line if $res->is_error;

    return $res->content;
}

sub _get_args {
    my ($self, $content) = @_;

    my $data;
    for (split "\n", $content) {
        if ($_ && /var\s+swfConfig\s+=/) {
            my ($json) = $_ =~ /^[^{]+(.*)[^}]+$/;
            $data = JSON->new->utf8(1)->decode($json);
            last;
        }
    }

    return $data->{args};
}

sub _parse_fmt_url_map {
    my $param = shift;
    my $fmt_url_map = {};
    for my $stuff (split ',', $param) {
        my ($fmt, $playback_url) = split '\|', $stuff, 2;
        $fmt_url_map->{$fmt} = $playback_url;
    }

    return $fmt_url_map;
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

sub ua {
    my $self = shift;
    my $ua = shift || return $self->{ua};
    Carp::croak "Usage: $self->ua(\$LWP_LIKE_OBJECT)" unless eval { $ua->isa('LWP::UserAgent') };
    $self->{ua} = $ua;
}

sub _suffix {
    my $fmt = shift;
    return $fmt =~ /18|22|37/ ? '.mp4'
         : $fmt =~ /13|17/    ? '.3gp'
         :                      '.flv'
    ;
}

sub _video_id {
    my $stuff = shift;
    if ($stuff =~ m{/.*?[?&;]v=([^&#?=/;]+)}) {
        return $1;
    }
    elsif ($stuff =~ m{/(?:e|v|embed)/([^&#?=/;]+)}) {
        return $1;
    }
    elsif ($stuff =~ m{#p/(?:u|search)/\d+/([^&?/]+)}) {
        return $1;
    }
    else {
        return $stuff;
    }
}

1;
__END__

=head1 NAME

WWW::YouTube::Download - Very simply YouTube video download interface.

=head1 SYNOPSIS

  use WWW::YouTube::Download;
  
  my $client = WWW::YouTube::Download->new;
  $client->download($video_id);
  
  my $video_url = $client->get_video_url($video_id);
  my $title     = $client->get_title($video_id);     # maybe encoded utf8 string.
  my $fmt       = $client->get_fmt($video_id);       # maybe highest quality.

=head1 DESCRIPTION

WWW::YouTube::Download is a download video from YouTube.

=head1 METHODS

=over

=item B<new()>

  $client = WWW::YouTube::Download->new;

Creates a WWW::YouTube::Donwload instance.

=item B<download($video_id [, \%args])>

  $client->download($video_id);
  $client->download($video_id, {
      fmt       => 37,
      file_name => 'sample.mp4', # save file name
  });
  $client->download($video_id, {
      cb => \&callback,
  });

Download the video file.
The first parameter is passed to YouTube video url.
B<\&callback> details SEE ALSO L<LWP::UserAgent> ':content_cb'.

=item B<ua([$ua])>

  $self->ua->agent();
  $self->ua($LWP_LIKE_OBJECT);

Sets and gets LWP::UserAgent object.

=item B<get_video_url($video_id)>

=item B<get_title($video_id)>

=item B<get_fmt($video_id)>

=back

=head1 AUTHOR

Yuji Shimada

=head1 CONTRIBUTORS

yusukebe

=head1 SEE ALSO

L<WWW::NicoVideo::Download>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
