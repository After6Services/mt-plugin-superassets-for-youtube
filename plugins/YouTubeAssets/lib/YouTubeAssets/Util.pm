package YouTubeAssets::Util;

use strict;
use warnings;

require MT;

use Exporter qw(import);
our @ALL = qw(
    is_valid_video_url
    video_id_from_url
    plugin
);
our @EXPORT_OK = @ALL;
our %EXPORT_TAGS = (all => \@ALL);

sub post_init {
    # always add our entry text filter
    no warnings 'redefine';

    require MT::Entry;
    my $orig_text_filters = \&MT::Entry::text_filters;

    *MT::Entry::text_filters = sub {
        my $filters = $orig_text_filters->(@_);
        unshift @$filters, 'embed_youtube_videos';
        return $filters;
    };
}

#
# YouTube video URLs:
#
# http://www.youtube.com/watch?v=9KnyZH6PADg
# http://youtu.be/9KnyZH6PADg
#
sub is_valid_video_url {
    my $url = shift;
    return $url && $url =~ m'^\s* (?:https?://)? (?:www\.)? (?: youtube\.com/watch\?v=[\w-]+ | youtu\.be/[\w-]+ ) \s*$'xi;
}

#
# Get video id from a URL
#
# http://youtube.com/watch?v=kux5dxuJCi4
# http://youtu.be/kux5dxuJCi4
#
sub video_id_from_url {
    my $url = shift or return;
    return ( $url =~ m'youtube\.com/watch\?v=([\w-]+)'i || $url =~ m'youtu\.be/([\w-]+)'i ) ? $1 : undef;
}

sub embed_filter {
    my ($text, $ctx) = @_;

    # replacing RTE-compatible video placeholder tags with actual embed code
    # <mt:youtube asset-id="xxx" [other params]>...</mt:youtube>
    if ($text) {
        $text =~ s|<mt:youtube\s+(.*?)>.*?</mt:youtube>|embed_video($1)|iseg;
    }

    return $text;
}

sub embed_video {
    my ($param_str) = @_;
    my %params;

    # parsing key=value attributes of the video placeholder tag
    while ($param_str =~ /([\w\-:]+) \s* = \s* (['"]?) (.*?) \2/igsx) {
        $params{$1} = $3;
    }

    $params{blog_id} = delete $params{'blog-id'};
    $params{asset_id} = delete $params{'asset-id'};

    require MT::Asset;
    my $asset = MT::Asset->load($params{'asset_id'});

    return $asset ? $asset->as_html({ embed_code => 1, %params }) : '';
}

sub plugin {
    return MT->component("YouTubeAssets");
}

1;
