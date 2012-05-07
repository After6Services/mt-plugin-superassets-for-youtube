package MT::Asset::YouTubeVideo;

use strict;
use warnings;

use base 'MT::Asset';

require MT;
require MT::Util;
use YouTubeAssets::Util qw(:all);

__PACKAGE__->install_properties({
    class_type  => 'youtube_video',
    column_defs => {
        youtube_video_id         => 'string meta indexed',
        youtube_video_thumbnails => 'hash meta',
        youtube_video_user_id    => 'string meta indexed',
        youtube_video_user_name  => 'string meta indexed',
    },
});

sub class_label { "YouTube Video" }   

sub class_label_plural { "YouTube Videos" }

sub has_thumbnail { 1 }

# entry asset manager needs this
sub file_name { shift->label }

our @PLAYER_SIZES = (
    { width => 560,  height => 315 },
    { width => 640,  height => 360 },
    { width => 853,  height => 480 },
    { width => 1280, height => 720 },
);
our $DEFAULT_PLAYER_SIZE = '640x360';

#
# Unlike the original version for image assets, this function selects a best-matching
# YouTube thumbnail size and then adjusts the image dimensions to width and/or
# height params to allow image scaling in html.
#
# YouTube's common thumbnails with typical sizes:
#     - default: 120x90px
#     - mqdefault: 320x180px
#     - hqdefault: 480x360px
#
sub thumbnail_url {
    my ($asset, %param) = @_;

    my $size = $asset->best_thumb_size(%param);
    my $thumbs = $asset->youtube_video_thumbnails;

    my ($w, $h) = @param{qw/width height/};
    $w ||= $param{Width};
    $h ||= $param{Height};

    my ($new_w, $new_h);
    my $ratio = $thumbs->{$size}->{width} / $thumbs->{$size}->{height};

    if ($w && (!$h || int($w / $ratio) <= $h)) {
        $new_w = $w;
        $new_h = int($new_w / $ratio);
    }
    elsif ($h) {
        $new_h = $h;
        $new_w = int($new_h * $ratio);
    }

    return (
        sprintf(
            'http://i.ytimg.com/vi/%s/%s.jpg',
            $asset->youtube_video_id,
            $size
        ),
        $new_w || $thumbs->{$size}->{width},
        $new_h || $thumbs->{$size}->{height},
    );
}

#
# Returns name of a thumbnail size better matching given $w/$h from the list of
# thumbnails the video has on YouTube; falls back to 'default'.
#
sub best_thumb_size {
    my ($asset, %params) = @_;
    my ($w, $h) = @params{qw/width height/};
    my $thumbs = $asset->youtube_video_thumbnails;

    $w ||= $params{Width};
    $h ||= $params{Height};

    return 'default' unless $w || $h;

    if ($thumbs && keys %$thumbs) {
        my %sizes_delta = map {
            my $delta;
            $delta += abs($w - $thumbs->{$_}->{width}) if $w;
            $delta += abs($h - $thumbs->{$_}->{height}) if $h;
            $delta => $_;
        } keys %$thumbs;
        
        return $sizes_delta{ ( sort { $a <=> $b } keys %sizes_delta )[0] };
    }

    return 'default';
}

sub insert_options {
    my ($asset, $param) = @_;
    my $app = MT->instance;
    my $blog = $asset->blog;
    my $prefs = $blog->youtube_video_embed_options;

    my @sizes = map {
        {
            name  => "$_->{width} × $_->{height}",
            value => "$_->{width}x$_->{height}",
        }
    } @PLAYER_SIZES;
    $param->{sizes} = \@sizes;

    $param->{default_size} = $prefs->{size} || $DEFAULT_PLAYER_SIZE;
    @$param{qw/width height/} = @$prefs{qw/width height/};

    for (qw(none left center right)) {
        $param->{"align_$_"} = ($prefs->{align} || 'none') eq $_ ? 1 : 0;
    }

    $param->{can_save_settings} = $app->permissions->can_save_image_defaults ? 1 : 0;

    return $app->build_page(
        plugin->load_tmpl('video_insert_options.tmpl'), $param
    );
}

sub on_upload {
    my $asset = shift;
    my ($param) = @_;
    my $app = MT->instance;
    my $blog = $asset->blog;

    $asset->SUPER::on_upload(@_);

    return unless $param->{new_entry};

    if ($param->{save_settings}) {
        return $app->error("Permission denied saving YouTube settings for blog " . $blog->id)
            unless $app->permissions->can_save_image_defaults;

        my $options = $blog->youtube_video_embed_options;
        $options->{align} = $param->{align} || 'none';

        $options->{size} = $param->{size} || $DEFAULT_PLAYER_SIZE;

        $options->{$_} = $param->{$_}
            for grep { $param->{$_} && $param->{$_} =~ /^\d+$/ } qw(width height);

        $blog->youtube_video_embed_options($options);
        $blog->save or die $blog->errstr;
    }
}

sub as_html {
    my ($asset, $param) = @_;

    if ($param->{embed_code}) {
        # called from our text filter - generating the final embed code to be published

        die "Couldn't generate YouTube video embed code: missing target blog_id for asset " . $asset->id
            unless $param->{blog_id};

        # try using a blog-level or system-wide module "YouTube Player"
        require MT::Template;
        my ($tmpl) = MT::Template->load(
            {
                type    => 'custom',
                name    => 'YouTube Player',
                blog_id => [ $param->{blog_id}, 0 ],
            },
            {
                sort      => 'blog_id',
                direction => 'descend',
            },
        );

        # or the default one
        $tmpl ||= plugin->load_tmpl('video_player.tmpl');

        require MT::Template::Context;
        my $ctx = MT::Template::Context->new;
        $ctx->stash('blog', $asset->blog);
        $ctx->stash('asset', $asset);
        $tmpl->context($ctx);
        $tmpl->param($param);

        my $html = $tmpl->build;
        die "Couldn't generate YouTube video embed code: " . $tmpl->errstr
            unless defined $html;

        return $html;
    }
    else {
        # RTE-compatible placeholder tag

        if ($param->{size} =~ /^(\d+)x(\d+)$/) {
            @$param{qw(width height)} = ($1, $2);
        }

        my $style = '';
        if ($param->{wrap_text} && $param->{align}) {
            $style = 'class="mt-image-' . $param->{align} . '" ';

            if ($param->{align} eq 'none') {
                $style .= q{style=""};
            }
            elsif ($param->{align} eq 'left') {
                $style .= q{style="float: left; margin: 0 20px 20px 0;"};
            }
            elsif ($param->{align} eq 'right') {
                $style .= q{style="float: right; margin: 0 0 20px 20px;"};
            }
            elsif ($param->{align} eq 'center') {
                $style .= q{style="text-align: center; display: block; margin: 0 auto 20px;"};
            }
        }

        return sprintf(
            '<mt:youtube asset-id="%s" blog-id="%s" %s %s><img src="%s" width="%s" height="%s"/></mt:youtube>',
            $asset->id,
            $param->{blog_id},
            join(' ', map { qq|$_="$param->{$_}"| } qw(width height align)),
            $style,
            $asset->thumbnail_url(width => 320)
        );
    }
}

sub edit_template_param {
    my $asset = shift;
    my ($cb, $app, $param, $tmpl) = @_;
    return;
}

1;
