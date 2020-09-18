package WWW::YouTube::Download;

use strict;
use warnings;
use 5.008001;

our $VERSION = '0.64';

use Carp qw(croak);
use URI ();
use LWP::UserAgent;
use JSON::MaybeXS 'JSON';
use HTML::Entities qw/decode_entities/;
use HTTP::Request;
use MIME::Type;

$Carp::Internal{ (__PACKAGE__) }++;

use constant DEFAULT_FMT => 18;

my $base_url = 'https://www.youtube.com/watch?v=';

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
    ## no critic (TestingAndDebugging::ProhibitNoStrict)
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
        progress  => $args->{progress},
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
    defined($data->{video_url_map}{$fmt}{url}) ? 1 : 0;
}

sub _progress {
    my ($self, $args, $total) = @_;

    if (not defined $args->{_progress}) {
        eval "require Term::ProgressBar" or return;    ## no critic
        $args->{_progress} = Term::ProgressBar->new( { count => $total, ETA => 'linear', remove => 0, fh => \*STDOUT } );
        $args->{_progress}->minor( $total > 50_000_000 ? 1 : 0 );
        $args->{_progress}->max_update_rate(1);

        $args->{_progress}->message("Total $total");
    }

    return $args->{_progress};
}

sub _default_cb {
    my ($self, $args) = @_;
    my ($file, $verbose, $overwrite, $progress) = @$args{qw/filename verbose overwrite progress/};

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

            if ($progress) {
                if (my $p = $self->_progress($args, $total)){
                    $p->update($size);
                    return;
                }
                else{
                    print "(You need Term::ProgressBar module to show progress bar with -P switch)\n";
                    $progress = 0;
                }
            }

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

    my ($title, $user, $video_url_map);
    my $content = $self->_get_content($video_id);
    if ($self->_is_new($content)) {
      my $args        = $self->_get_args($content);
      my $player_resp = JSON()->new->decode($args->{player_response});
      $video_url_map  = $self->_decode_player_response($player_resp);
      $title          = decode_entities $player_resp->{videoDetails}{title};
      $user           = decode_entities $player_resp->{videoDetails}{author};
    } else {
      $title         = $self->_fetch_title($content);
      $user          = $self->_fetch_user($content);
      $video_url_map = $self->_fetch_video_url_map($content);
    }

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

sub _mime_to_suffix {
    (my $mime = shift) =~ s{^([^;]+);.*}{$1};
    my $stype = MIME::Type->new(type => $mime)->subType;
    return $stype eq 'webm' ? 'webm'
         : $stype eq 'mp4'  ? 'mp4'
         : $stype eq '3gp'  ? '3gp'
         :                   'flv'
    ;
}

sub _decode_player_response {
  my ($self, $player_data) = @_;
  # need to decode $player_data->{streamingData}{formats};
  my $fmt_map = { map { $_->{mimeType} => join 'x', $_->{width}, $_->{height} } @{$player_data->{streamingData}{formats}} };
  my $fmt_url_map = { map { $_->{mimeType} => $_->{url} } @{$player_data->{streamingData}{formats}} };
  # more formats in $player_data->{streamingData}{adaptiveFormats};
  return +{
      map {
          $_->{fmt} => $_,
      } map +{
          fmt        => $_,
          resolution => $fmt_map->{$_},
          url        => $fmt_url_map->{$_},
          suffix     => _mime_to_suffix($_),
      }, keys %$fmt_map
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
    }elsif( $content =~ /","author":"([^"]+)","/ ){
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
        elsif ($line =~ /^.+ytplayer\.config\s*=\s*(\{.*})/) {
            ($data, undef) = JSON->new->utf8(1)->decode_prefix($1);
            last;
        }
    }

    croak 'failed to extract JSON data' unless $data->{args};

    return $data->{args};
}

sub _is_new {
    my ($self, $content) = @_;
    my $args = $self->_get_args($content);
    return 1 unless ($args->{fmt_list} and $args->{url_encoded_fmt_stream_map});
    return 0;
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
    if (@s == 93) {
        return (reverse(@s[30..86]), $s[88], reverse(@s[6..28]));
    } elsif (@s == 92) {
        return ($s[25], @s[3..24], $s[0], @s[26..41], $s[79], @s[43..78], $s[91], @s[80..82]);
    } elsif (@s == 91) {
        return (reverse(@s[28..84]), $s[86], reverse(@s[6..26]));
    } elsif (@s == 90) {
        return ($s[25], @s[3..24], $s[2], @s[26..39], $s[77], @s[41..76], $s[89], @s[78..80]);
    } elsif (@s == 89) {
        return (reverse(@s[79..84]), $s[87], reverse(@s[61..77]), $s[0], reverse(@s[4..59]));
    } elsif (@s == 88) {
        return (@s[7..27], $s[87], @s[29..44], $s[55], @s[46..54], $s[2], @s[56..86], $s[28]);
    } elsif (@s == 87) {
        return (@s[6..26], $s[4], @s[28..38], $s[27], @s[40..58], $s[2], @s[60..86]);
    } elsif (@s == 86) {
        return (@s[4..30], $s[3], @s[32..84]);
    } elsif (@s == 85) {
        return (@s[3..10], $s[0], @s[12..54], $s[84], @s[56..83]);
    } elsif (@s == 84) {
        return (reverse(@s[71..78]), $s[14], reverse(@s[38..69]), $s[70], reverse(@s[15..36]), $s[80], reverse(@s[0..13]));
    } elsif (@s == 83) {
        return (reverse(@s[64..80]), $s[0], reverse(@s[1..62]), $s[63]);
    } elsif (@s == 82) {
        return (reverse(@s[38..80]), $s[7], reverse(@s[8..36]), $s[0], reverse(@s[1..6]), $s[37]);
    } elsif (@s == 81) {
        return ($s[56], reverse(@s[57..79]), $s[41], reverse(@s[42..55]), $s[80], reverse(@s[35..40]), $s[0], reverse(@s[30..33]), $s[34], reverse(@s[10..28]), $s[29], reverse(@s[1..8]), $s[9]);
    } elsif (@s == 80) {
        return (@s[1..18], $s[0], @s[20..67], $s[19], @s[69..79]);
    } elsif (@s == 79) {
        return ($s[54], reverse(@s[55..77]), $s[39], reverse(@s[40..53]), $s[78], reverse(@s[35..38]), $s[0], reverse(@s[30..33]), $s[34], reverse(@s[10..28]), $s[29], reverse(@s[1..8]), $s[9]);
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
        my $sig = $query->{sig} || ($query->{s} ? _getsig($query->{s}) : undef);
        my $url = $query->{url};
        $fmt_url_map->{$query->{itag}} = $url . ($sig ? '&signature='.$sig : '');
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
    return $fmt =~ /43|44|45|46/ ? 'webm'
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

sub playlist {
	my ($self, $id, $args) = @_;

	my $fetchCnt = 1;
	my $html = $self->_fetch_playlist($id);

	my ($videos,$nextUrl) = $self->_find_playlist_videos($html);

	return $videos unless $nextUrl;
	return $videos if $args && $args->{limit} && $fetchCnt >= $args->{limit};

	while($nextUrl){
		$fetchCnt++;
		my $json = $self->_fetch_playlist_json($nextUrl);

		(my $moreVideos,$nextUrl) = $self->_find_playlist_json_videos($json);

		push(@$videos, @$moreVideos);

		last unless $nextUrl;
		last if $args && $args->{limit} && $fetchCnt >= $args->{limit};
	}

	return $videos;
}

sub _fetch_playlist {
    my $self = shift;
    my $id = shift;
    my $url = 'https://www.youtube.com/playlist?list='. $id;

    print 'Fetching playlist page '. $url .' ... ' if $self->{verbose};

    my $res = $self->ua->get($url);

    croak('Error: fetch_playlist failed for url:'. $url .' status:'. $res->status_line) unless $res->is_success;

    print "ok \n" if $self->{verbose};

    return $res->decoded_content;
}

sub _find_playlist_videos {
	my $self = shift;
	my $html = shift;

	## find JSON blob
	my $line;
	for( split("\n", $html) ){
		if($_ =~ /window\["ytInitialData"\]/){
			$line = $_;
			last;
		}
	}

	die "Error: could not find YT JSON data!" unless $line;

	my $start = index($line, '{');
	my $end = rindex($line, '}');
	my $json = substr($line, $start, $end - $start + 1);

	my $ref = JSON()->new->utf8(0)->decode($json);

	## drill into YT's data structure
	die "Error: YT JSON data not structed as expected!" unless
	$ref->{contents} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs} && ref($ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}) eq 'ARRAY' &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0] &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents} && ref($ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}) eq 'ARRAY' &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0] &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents} && ref($ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents}) eq 'ARRAY' &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents}->[0] &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents}->[0]->{playlistVideoListRenderer} &&
	$ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents}->[0]->{playlistVideoListRenderer}->{contents} && ref($ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents}->[0]->{playlistVideoListRenderer}->{contents}) eq 'ARRAY'
	;

	my $playlistVideoListRenderer = $ref->{contents}->{twoColumnBrowseResultsRenderer}->{tabs}->[0]->{tabRenderer}->{content}->{sectionListRenderer}->{contents}->[0]->{itemSectionRenderer}->{contents}->[0]->{playlistVideoListRenderer};

	## weed out videos
	my @videos;
	my $cnt = 0;
	for my $renderer (@{ $playlistVideoListRenderer->{contents} }){
		$cnt++;
		my $video = $renderer->{playlistVideoRenderer};

		push(@videos, {
			id	=> $video->{videoId},
			runtime => $video->{lengthSeconds},
			title	=> ($video->{title}->{simpleText}||'undef'), # encoded in Perl internal
		});

		if($self->{verbose}){
			print " $cnt id:". $video->{videoId};
			print " runtime:". ($video->{lengthSeconds}||'undef');
			print " title:". Encode::encode_utf8($video->{title}->{simpleText}||'undef');
			print "\n";
		}
	}

	## next page
	my $nextUrl;
	if(	$playlistVideoListRenderer->{continuations} && ref($playlistVideoListRenderer->{continuations}) eq 'ARRAY' &&
		$playlistVideoListRenderer->{continuations}->[0] &&
		$playlistVideoListRenderer->{continuations}->[0]->{nextContinuationData}
	){
		my $next = $playlistVideoListRenderer->{continuations}->[0]->{nextContinuationData};
		my $continuation = $next->{continuation};
		my $ctoken = $continuation;
		my $itct = $next->{clickTrackingParams};

		if($self->{verbose}){
			print " next page continuation data:\n cont:". $continuation ."\n";
			print " itct:". $itct ."\n";
			print "\n";
		}

		$nextUrl = 'https://www.youtube.com/browse_ajax?ctoken='. $ctoken .'&continuation='. $continuation .'&itct='. $itct;
	}

    return (\@videos,$nextUrl);
}

sub _fetch_playlist_json {
    my $self = shift;
    my $url = shift;

    print 'Fetching playlist next page '. $url .' ... ' if $self->{verbose};

    my $res = $self->ua->get($url,
	# thanks youtube-dl for the hint towards these headers
        'x-youtube-client-name' => '1',
        'x-youtube-client-version' => '2.20200825.04.00', # version '1.20200609.04.02' will return a HTML blob in content_html, this version returns only JSON
	);

    croak('Error: fetch_playlist_json failed for url:'. $url .' status:'. $res->status_line) unless $res->is_success;

    print "ok \n" if $self->{verbose};

    return $res->decoded_content;
}

sub _find_playlist_json_videos {
	my $self = shift;
	my $json = shift;

	my $ref = JSON()->new->utf8(1)->decode($json);

	## drill into YT's data structure
	die "Error: YT JSON data not structed as expected!" unless
	ref($ref) eq 'ARRAY' &&
	$ref->[1] &&
	$ref->[1]->{response} &&
	$ref->[1]->{response}->{continuationContents} &&
	$ref->[1]->{response}->{continuationContents}->{playlistVideoListContinuation} &&
	$ref->[1]->{response}->{continuationContents}->{playlistVideoListContinuation}->{contents} && ref($ref->[1]->{response}->{continuationContents}->{playlistVideoListContinuation}->{contents}) eq 'ARRAY'
	;

	my $playlistVideoListContinuation = $ref->[1]->{response}->{continuationContents}->{playlistVideoListContinuation};

	## weed out videos
	my @videos;
	my $cnt = 0;
	for my $renderer (@{ $playlistVideoListContinuation->{contents} }){
		$cnt++;
		my $video = $renderer->{playlistVideoRenderer};

		push(@videos, {
			id	=> $video->{videoId},
			runtime => $video->{lengthSeconds},
			title	=> ($video->{title}->{simpleText}||'undef'), # encoded in Perl internal
		});

		if($self->{verbose}){
			print " $cnt id:". $video->{videoId};
			print " runtime:". ($video->{lengthSeconds}||'undef');
			print " title:". Encode::encode_utf8($video->{title}->{simpleText}||'undef');
			print "\n";
		}
	}

	## next page
	my $nextUrl;
	if(	$playlistVideoListContinuation->{continuations} && ref($playlistVideoListContinuation->{continuations}) eq 'ARRAY' &&
		$playlistVideoListContinuation->{continuations}->[0] &&
		$playlistVideoListContinuation->{continuations}->[0]->{nextContinuationData}
	){
		my $next = $playlistVideoListContinuation->{continuations}->[0]->{nextContinuationData};
		my $continuation = $next->{continuation};
		my $ctoken = $continuation;
		my $itct = $next->{clickTrackingParams};

		if($self->{verbose}){
			print " next page continuation data:\n cont:". $continuation ."\n";
			print " itct:". $itct ."\n";
			print "\n";
		}

		$nextUrl = 'https://www.youtube.com/browse_ajax?ctoken='. $ctoken .'&continuation='. $continuation .'&itct='. $itct;
	}

	return (\@videos, $nextUrl);
}

1;
__END__

# ABSTRACT: WWW::YouTube::Download - Very simple YouTube video download interface

=head1 SYNOPSIS

  use WWW::YouTube::Download;

  my $client = WWW::YouTube::Download->new;
  $client->download($video_id);

  my $video_url = $client->get_video_url($video_id);
  my $title     = $client->get_title($video_id);     # maybe encoded utf8 string.
  my $fmt       = $client->get_fmt($video_id);       # maybe highest quality.
  my $suffix    = $client->get_suffix($video_id);    # maybe highest quality file suffix

=head1 DESCRIPTION

WWW::YouTube::Download is a library to download videos from YouTube. It relies entirely on
scraping a video's webpage and does not use YT's /get_video_info URL space.

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

=item B<get_video_id($video_id)>

=item B<get_video_url($video_id)>

=item B<get_title($video_id)>

=item B<get_user($video_id)>

=item B<get_fmt($video_id)>

=item B<get_fmt_list($video_id)>

=item B<get_suffix($video_id)>

=item B<playlist($id,$ref)>

Fetches a playlist and returns a ref to an array of hashes, where each hash
represents a video from the playlist with youtube id, runtime in seconds
and title. On playlists with many videos, the method iteratively downloads
pages until the playlist is complete.

Optionally accepts a second argument, a hashref of options. Currently, you
can pass a "limit" value to stop downloading of subsequent pages on larger
playlists after x-amount of fetches (a limit of fetches, not playlist items).
For example, pass 1 to only download the first page of videos from a playlist
in order to "skim" the "tip" of new videos in a playlist. YouTube currently
returns 100 videos at max per page.

This method is used by the I<youtube-playlists.pl> script.

=back

=head1 CONTRIBUTORS

yusukebe

=head1 BUG REPORTING

Please use github issues: L<< https://github.com/xaicron/p5-www-youtube-download/issues >>.

=head1 SEE ALSO

L<WWW::YouTube::Info> and L<WWW::YouTube::Info::Simple>.
L<WWW::NicoVideo::Download>
L<http://rg3.github.io/youtube-dl/>

=cut
