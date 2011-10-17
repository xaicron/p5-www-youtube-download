package WWW::YouTube::Download;

use strict;
use warnings;
use 5.008001;

our $VERSION = '0.35';

use Carp ();
use URI ();
use LWP::UserAgent;
use JSON;
use HTML::Entities qw/decode_entities/;

use constant DEFAULT_FMT => 18;

my $base_url = 'http://www.youtube.com/watch?v=';
my $info     = 'http://www.youtube.com/get_video_info?video_id=';

sub new {
    my $class = shift;
    my %args = @_;
    $args{ua} = LWP::UserAgent->new(
        agent => __PACKAGE__.'/'.$VERSION,
    ) unless exists $args{ua};
    bless \%args, $class;
}

for my $name (qw[video_id video_url title fmt fmt_list suffix]) {
    no strict 'refs';
    *{"get_$name"} = sub {
        use strict 'refs';
        my ($self, $video_id) = @_;
        Carp::croak "Usage: $self->get_$name(\$video_id|\$watch_url)" unless $video_id;
        my $data = $self->prepare_download($video_id);
        return $data->{$name};
    };
}

sub download {
    my ($self, $video_id, $args) = @_;
    Carp::croak "Usage: $self->download('[video_id|video_url]')" unless $video_id;
    $args ||= {};

    my $data = $self->prepare_download($video_id);

    my $fmt = $args->{fmt} || $data->{fmt} || DEFAULT_FMT;

    my $video_url = $data->{video_url_map}{$fmt}{url} || Carp::croak "this video has not supported fmt: $fmt";
    my $file_name = $self->_foramt_file_name($args->{file_name}, {
        video_id   => $data->{video_id},
        title      => $data->{title},
        fmt        => $fmt,
        suffix     => $data->{video_url_map}{$fmt}{suffix} || _suffix($fmt),
        resolution => $data->{video_url_map}{$fmt}{resolution} || '0x0',
    });

    $args->{cb} = $self->_default_cb({
        file_name => $file_name,
        verbose   => $args->{verbose},
        overwrite => defined $args->{overwrite} ? $args->{overwrite} : 1,
    }) unless ref $args->{cb} eq 'CODE';

    my $res = $self->ua->get($video_url, ':content_cb' => $args->{cb});
    Carp::croak "!! $video_id download failed: ", $res->status_line if $res->is_error;
}

sub _foramt_file_name {
    my ($self, $file_name, $data) = @_;
    return "$data->{video_id}.$data->{suffix}" unless defined $file_name;
    $file_name =~ s#{([^}]+)}#$data->{$1} || "{$1}"#eg;
    return $file_name;
}

sub _is_supported_fmt {
    my ($self, $video_id, $fmt) = @_;
    my $data = $self->prepare_download($video_id);
    $data->{video_url_map}{$fmt}{url} ? 1 : 0;
}

sub _default_cb {
    my ($self, $args) = @_;
    my ($file, $verbose, $overwrite) = @$args{qw/file_name verbose overwrite/};

    Carp::croak "file exists! $file" if -f $file and !$overwrite;
    open my $wfh, '>', $file or die $file, " $!";
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
    Carp::croak "Usage: $self->prepare_download('[video_id|watch_url]')" unless $video_id;
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
        fmt_list      => $fmt_list,
        suffix        => $hq_data->{suffix},
    };
}

sub _fetch_title {
    my ($self, $content) = @_;

    my ($title) = $content =~ /<meta name="title" content="(.+?)">/ or return;
    return decode_entities($title);
}

sub _fetch_video_url_map {
    my ($self, $content) = @_;

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    my $args = $self->_get_args($content);
    unless ($args->{fmt_list} and $args->{url_encoded_fmt_stream_map}) {
        Carp::croak 'failed to find video urls';
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

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    my $url = "$base_url$video_id";
    my $res = $self->ua->get($url);
    Carp::croak "GET $url failed. status: ", $res->status_line if $res->is_error;

    return $res->content;
}

sub _get_args {
    my ($self, $content) = @_;

    my $data;
    for my $line (split "\n", $content) {
        next unless $line;
        if ($line =~ /^\s*'PLAYER_CONFIG'\s*:\s*({.*})\s*$/) {
            $data = JSON->new->utf8(1)->decode($1);
            last;
        }
    }

    Carp::croak 'failed to extract JSON data.' unless $data->{args};

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

sub _parse_stream_map {
    my $param       = shift;
    my $fmt_url_map = {};
    for my $stuff (split ',', $param) {
        my $uri = URI->new;
        $uri->query($stuff);
        my $query = +{ $uri->query_form };
        $fmt_url_map->{$query->{itag}} = $query->{url};
    }

    return $fmt_url_map;
}

sub ua {
    my ($self, $ua) = @_;
    return $self->{ua} unless $ua;
    Carp::croak "Usage: $self->ua(\$LWP_LIKE_OBJECT)" unless eval { $ua->isa('LWP::UserAgent') };
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

sub _video_id {
    my $stuff = shift;
    if ($stuff =~ m{/.*?[?&;!]v=([^&#?=/;]+)}) {
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
      fmt       => 37,
      file_name => 'sample.mp4', # save file name
  });
  $client->download($video_id, {
      file_name => '{title}.{suffix}', # maybe `video_title.mp4`
  });
  $client->download($video_id, {
      cb => \&callback,
  });

Download the video file.
The first parameter is passed to YouTube video url.
B<\&callback> details SEE ALSO L<LWP::UserAgent> ':content_cb'.

C<< file_name >> supported format:

  {video_id}
  {title}
  {fmt}
  {suffix}
  {resolution}

=item B<ua([$ua])>

  $self->ua->agent();
  $self->ua($LWP_LIKE_OBJECT);

Sets and gets LWP::UserAgent object.

=item B<get_video_url($video_id)>

=item B<get_title($video_id)>

=item B<get_fmt($video_id)>

=item B<get_fmt_list($video_id)>

=item B<get_suffix($video_id)>

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
