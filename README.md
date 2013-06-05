# NAME

WWW::YouTube::Download - Very simple YouTube video download interface

# SYNOPSIS

    use WWW::YouTube::Download;

    my $client = WWW::YouTube::Download->new;
    $client->download($video_id);

    my $video_url = $client->get_video_url($video_id);
    my $title     = $client->get_title($video_id);     # maybe encoded utf8 string.
    my $fmt       = $client->get_fmt($video_id);       # maybe highest quality.
    my $suffix    = $client->get_suffix($video_id);    # maybe highest quality file suffix

# DESCRIPTION

WWW::YouTube::Download is a download video from YouTube.

# METHODS

- __new()__

        $client = WWW::YouTube::Download->new;

    Creates a WWW::YouTube::Download instance.

- __download($video\_id \[, \\%args\])__

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

        Set a callback subroutine, SEE [LWP::UserAgent](http://search.cpan.org/perldoc?LWP::UserAgent) ':content\_cb'
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

        __DEPRECATED__ alternative for `filename`.

    - `fmt`

        set the format to download. Defaults to the best video quality
        (inferred by the available resolutions).



- __playback\_url($video\_id, \[, \\%args\])__

        $client->playback_url($video_id);
        $client->playback_url($video_id, { fmt => 37 });

    Return playback URL of the video. This is direct link to the movie file.
    Function supports only "fmt" option.

- __prepare\_download($video\_id)__

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

- __ua(\[$ua\])__

        $self->ua->agent();
        $self->ua($LWP_LIKE_OBJECT);

    Sets and gets LWP::UserAgent object.

- __video\_id($url)__

    Parses given URL and returns video ID.

- __playlist\_id($url)__

    Parses given URL and returns playlist ID.

- __user\_id($url)__

    Parses given URL and returns YouTube username.

- __get\_video\_url($video\_id)__
- __get\_title($video\_id)__
- __get\_user($video\_id)__
- __get\_fmt($video\_id)__
- __get\_fmt\_list($video\_id)__
- __get\_suffix($video\_id)__

# AUTHOR

xaicron <xaicron {@} cpan.org>

# CONTRIBUTORS

yusukebe

# BUG REPORTING

Plese use github issues: [https://github.com/xaicron/p5-www-youtube-download/issues](https://github.com/xaicron/p5-www-youtube-download/issues).

# SEE ALSO

[WWW::NicoVideo::Download](http://search.cpan.org/perldoc?WWW::NicoVideo::Download)

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
