# NAME

WWW::YouTube::Download - WWW::YouTube::Download - Very simple YouTube video download interface

[![Build Status](https://travis-ci.org/xaicron/p5-www-youtube-download.png?branch=master)](https://travis-ci.org/xaicron/p5-www-youtube-download)

# VERSION

version 0.63

# SYNOPSIS

    use WWW::YouTube::Download;

    my $client = WWW::YouTube::Download->new;
    $client->download($video_id);

    my $video_url = $client->get_video_url($video_id);
    my $title     = $client->get_title($video_id);     # maybe encoded utf8 string.
    my $fmt       = $client->get_fmt($video_id);       # maybe highest quality.
    my $suffix    = $client->get_suffix($video_id);    # maybe highest quality file suffix

# DESCRIPTION

WWW::YouTube::Download is a library to download videos from YouTube. It relies entirely on
scraping a video's webpage and does not use YT's /get\_video\_info URL space.

# METHODS

- **new()**

        $client = WWW::YouTube::Download->new;

    Creates a WWW::YouTube::Download instance.

- **download($video\_id \[, \\%args\])**

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

    - `cb`

        Set a callback subroutine, SEE [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent) ':content\_cb'
        for details.

    - `filename`

        Set the filename, possibly using placeholders to be filled with
        information gathered about the video.

        `filename` supported format placeholders:

            {video_id}
            {title}
            {user}
            {fmt}
            {suffix}
            {resolution}

        Output filename is set to `{video_id}.{suffix}` by default.

    - `file_name`

        **DEPRECATED** alternative for `filename`.

    - `fmt`

        set the format to download. Defaults to the best video quality
        (inferred by the available resolutions).

- **playback\_url($video\_id, \[, \\%args\])**

        $client->playback_url($video_id);
        $client->playback_url($video_id, { fmt => 37 });

    Return playback URL of the video. This is direct link to the movie file.
    Function supports only "fmt" option.

- **prepare\_download($video\_id)**

    Gather data about the video. A hash reference is returned, with the following
    keys:

    - `fmt`

        the default, suggested format. It is inferred by selecting the
        alternative with the highest resolution.

    - `fmt_list`

        the list of available formats, as an array reference.

    - `suffix`

        the filename extension associated to the default format (see `fmt`
        above).

    - `title`

        the title of the video

    - `user`

        the YouTube user owning the video

    - `video_id`

        the video identifier

    - `video_url`

        the URL of the video associated to the default format (see `fmt`
        above).

    - `video_url_map`

        an hash reference containing details about all available formats.

    The `video_url_map` has one key/value pair for each available format,
    where the key is the format identifier (can be used as `fmt` parameter
    for ["download"](#download), for example) and the value is a hash reference with
    the following data:

    - `fmt`

        the format specifier, that can be passed to ["download"](#download)

    - `resolution`

        the resolution as _width_x_height_

    - `suffix`

        the suffix, providing a hint about the video format (e.g. webm, flv, ...)

    - `url`

        the URL where the video can be found

- **ua(\[$ua\])**

        $self->ua->agent();
        $self->ua($LWP_LIKE_OBJECT);

    Sets and gets LWP::UserAgent object.

- **video\_id($url)**

    Parses given URL and returns video ID.

- **playlist\_id($url)**

    Parses given URL and returns playlist ID.

- **user\_id($url)**

    Parses given URL and returns YouTube username.

- **get\_video\_id($video\_id)**
- **get\_video\_url($video\_id)**
- **get\_title($video\_id)**
- **get\_user($video\_id)**
- **get\_fmt($video\_id)**
- **get\_fmt\_list($video\_id)**
- **get\_suffix($video\_id)**

# CONTRIBUTORS

yusukebe

# BUG REPORTING

Please use github issues: [https://github.com/xaicron/p5-www-youtube-download/issues](https://github.com/xaicron/p5-www-youtube-download/issues).

# SEE ALSO

[WWW::YouTube::Info](https://metacpan.org/pod/WWW%3A%3AYouTube%3A%3AInfo) and [WWW::YouTube::Info::Simple](https://metacpan.org/pod/WWW%3A%3AYouTube%3A%3AInfo%3A%3ASimple).
[WWW::NicoVideo::Download](https://metacpan.org/pod/WWW%3A%3ANicoVideo%3A%3ADownload)
[http://rg3.github.io/youtube-dl/](http://rg3.github.io/youtube-dl/)

# AUTHOR

xaicron &lt;xaicron {@} cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Yuji Shimada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
