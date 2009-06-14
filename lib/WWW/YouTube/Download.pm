package WWW::YouTube::Download;

use strict;
use warnings;
use 5.008001;

our $VERSION = '0.02';

use Encode ();
use JSON ();
use Carp ();
use URI ();
use Web::Scraper ();
use LWP::UserAgent ();

use Any::Moose;
has 'quality',    is => 'rw', isa => 'Str';
has 'filename',   is => 'rw', isa => 'Str';
has 'verbose',    is => 'rw', isa => 'Int';
has 'video_url',  is => 'rw', isa => 'Str';
has 'fmt',        is => 'rw', isa => 'Int';
has 'encode',     is => 'rw', isa => 'Str',            default => 'utf8';
has 'user_agent', is => 'rw', isa => 'LWP::UserAgent', default => sub { LWP::UserAgent->new() };
has 'scraper',    is => 'ro', isa => 'Web::Scraper',   default => sub {
	Web::Scraper::scraper {
		Web::Scraper::process '/html/head/script', 'scripts[]' => 'html';
		Web::Scraper::process '//*[@id="watch-vid-title"]/h1', title => 'TEXT';
	};
};

my %quality = (
	high    => '35',
	low     => '6',
	normal  => '18',
);

sub download {
	my $self = shift;
	my $video_id = shift || Carp::croak "Usage $self->download('[video_id|video_url]')";
	my $cb = shift;
	
	$self->video_url( $self->get_video_url($video_id) );
	
	unless ($cb) {
		open my $wfh, '>', $self->filename or die $self->filename, " $!";
		binmode $wfh;
		$cb = sub {
			my ($chunk, $res, $proto) = @_;
			print $wfh $chunk;
			
			if ($self->verbose) {
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
	
	my $res = $self->user_agent->get($self->video_url, ':content_cb' => $cb);
	
	Carp::croak 'Download failed: ', $res->status_line if $res->is_error;
}

sub get_video_url {
	my $self = shift;
	my $video_id = shift || Carp::croak "Usage $self->get_video_id('[video_id|video_url]')";
	
	if ($video_id =~ /watch\?v=([^&]+)/) {
		$video_id = $1;
	}
	
	my $uri = URI->new("http://www.youtube.com/watch?v=$video_id") or die "$video_id error";
	
	my $result   = $self->scraper->scrape($uri) or die "failed scraping $uri";
	my $swfArgs  = $self->_get_swfArgs($result);
	$self->fmt( $self->_get_fmt($swfArgs) );
	
	unless ($self->filename) {
		$self->filename( $self->_get_filename($result->{title}) );
	}
	
	return sprintf "http://www.youtube.com/get_video?video_id=%s&t=%s&fmt=%s", $swfArgs->{video_id}, $swfArgs->{t}, $self->fmt;
}

sub _get_swfArgs {
	my $self = shift;
	my $result = shift;
	
	my $json;
	for my $line (split qq{\n}, join q{}, @{$result->{scripts}}) {
		if ($line =~ /^\s*var\s*swfArgs\s*=\s*({.*});/) {
			$json = HTML::Entities::decode_entities($1);
			last;
		}
	}
	
	return JSON::from_json $json or die 'JSON parse error';
}

sub _get_fmt {
	my $self = shift;
	my $swfArgs = shift;
	my $fmt;
	
	if ($self->quality) {
		$fmt = $self->qualiry =~ /^[0-9]+$/ ? $self->quality : $quality{$self->quality};
		Carp::croak 'unknown quality (', $self->quality, '). you must be [normal|high|low] or any numbers' unless $fmt;
	}
	
	else {
		for my $map (split /,/, $swfArgs->{fmt_map}) {
			next if $map =~ m|^(\d+)/(\d+)| and $2 eq '0';
			$fmt = $1;
			last;
		}
		
		$fmt = $quality{normal} unless $fmt;
	}
	
	return $fmt;
}

sub _get_filename {
	my $self = shift;
	my $title = shift;
	
	my $suffix = $self->fmt =~ /18|22/ ? '.mp4'
	           : $self->fmt =~ /13|17/ ? '.3gp'
	           :                   '.flv';
	
	return Encode::encode($self->encode, $title, sub {"U+%04X", shift}) . $suffix;
}

1;
__END__

=head1 NAME

WWW::YouTube::Download is a YouTube video download interface.

=head1 SYNOPSIS

  use WWW::YouTube::Download;
  
  my $client = WWW::YouTube::Download->new();
  $client->download($video_id);

=head1 DESCRIPTION

WWW::YouTube::Download is a YouTube video download interface.

=head1 METHODS

=over

=item B<new()>

  $client = WWW::YouTube::Download->new(
      encode   => $enc,      # default utf8
      filename => $filename, # default video title + suffix
      quality  => 'low',     # default auto
  );

=item B<download()>

  $client->download($video_id);
  $client->download($video_id, \&callback);

=item B<get_video_url()>

  my $url = $client->get_video_url();

=back

=head1 AUTHOR

Yuji Shimada E<lt>xaicron {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
