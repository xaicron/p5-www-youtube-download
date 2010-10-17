package WWW::YouTube::Download;

use strict;
use warnings;
use 5.008001;

our $VERSION = '0.15';

use CGI ();
use Carp ();
use URI ();
use LWP::UserAgent;
use URI::Escape qw/uri_unescape/;

use constant DEFAULT_FMT => 18;

my $info = 'http://www.youtube.com/get_video_info?video_id=';
my $down = "http://www.youtube.com/get_video?asv=2&video_id=%s&t=%s";

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
    
    my $fmt = $args->{fmt} || $data->{fmt};
    my $video_url = sprintf "%s&fmt=%d", $data->{video_url}, $fmt;
    my $file_name = $args->{file_name} || $data->{video_id} . _suffix($fmt);
    
    $args->{cb} = $self->_default_cb({
        file_name => $file_name,
        verbose   => $args->{verbose},
    }) unless ref $args->{cb} eq 'CODE';
    
    my $res = $self->ua->get($video_url, ':content_cb' => $args->{cb});
    Carp::croak 'Download failed: ', $res->status_line if $res->is_error;
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
    
    my $res = $self->ua->get("$info$video_id");
    
    local $Carp::CarpLevel = 1;
    Carp::croak "get info failed. status: ", $res->status_line if $res->is_error;
    
    my $params = CGI->new(uri_unescape $res->content);
    Carp::croak "$video_id not found" if $params->param('status') ne 'ok';
    
    my $fmt_list = [ do { my %h; sort { $b <=> $a } grep { !$h{$_}++ } ($params->param('itag'), DEFAULT_FMT) } ];
    my $fmt = $fmt_list->[0];
    
    return $self->{cache}{$video_id} = +{
        video_id  => $video_id,
        video_url => sprintf($down, $video_id, $params->param('token')),
        title     => $params->param('title'),
        fmt       => $fmt,
        fmt_list  => $fmt_list,
        suffix    => _suffix($fmt),
    };
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
    my $video_id = shift;
    $video_id =~ /watch\?v=([^&]+)/;
    return $1 || $video_id;
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
