package YouTubeAssets::CMS;

use strict;
use warnings;

require MT::Asset::YouTubeVideo;
use YouTubeAssets::Util qw(:all);
use Encode;

sub youtube_video_create {
    my $app = shift;
    my (%params, %errors, $tmpl, $video_id);

    return $app->error("Permission denied.")
        unless $app->user->is_superuser || $app->permissions && $app->permissions->can_upload;

    $params{$_} = $app->param($_) || '' for qw(video_url continue_args no_insert);

    # checking params preemptively passed via url or submitted with form
    if ($params{video_url}) {
        if (is_valid_video_url($params{video_url})) {
            if ( $video_id = video_id_from_url($params{video_url}) ) {
                if ( my ($v) = MT::Asset::YouTubeVideo->search_by_meta('youtube_video_id', $video_id) ) {
                    $params{original_asset_id} = $v->id;
                    $errors{video_already_exists} = 1;
                }
            }
        }
        else {
            $errors{invalid_video_url} = 1;
        }
    }

    if ($app->param("submit") && !keys %errors) {
        return unless $app->validate_magic;

        # checking required params
        unless ($video_id) {
            $errors{invalid_video_url} = 1;
        }
        else {
            # getting video metadata from youtube
            my $video;

            require MT;
            my $res = MT->new_ua->get("http://gdata.youtube.com/feeds/api/videos/$video_id?v=2&alt=json");

            if ($res->is_success) {
                require JSON;
                eval {
                    $video = JSON->new->allow_nonref->utf8(1)->decode($res->content) || {};
                };
                $errors{api_error} = $@ if $@;
            }
            else {
                if ($res->code eq '404') {
                    $errors{error_video_not_found} = 1;
                }
                elsif ($res->code eq '503') {
                    $errors{error_service_unavailable} = 1;
                }
                elsif ($res->code =~ /^5/) {
                    $errors{service_error} = 1;
                }
                elsif ($res->code eq '400' && $res->content && $res->content =~ /invalid id/i) {
                    $errors{error_video_not_found} = 1;
                }
                else {
                    $errors{api_error} = sprintf('(%s): %s', $res->code, $res->status_line);
                }
            }
            
            # some extra metadata checks
            unless (keys %errors) {
                $errors{api_data_error} = 1 unless ref $video->{entry};
            }

            unless (keys %errors) {
                # everything seems to be just swell, so let's create a new asset
                $video = $video->{entry};

                my $asset = MT::Asset::YouTubeVideo->new;
                $asset->blog_id($app->blog->id);
                $asset->label($video->{title}->{'$t'});
                $asset->description($video->{'media$group'}->{'media$description'}->{'$t'});
                $asset->url("http://www.youtube.com/watch?v=$video_id");
                $asset->modified_by($app->user->id);

                # youtube-specific stuff
                $asset->youtube_video_id($video_id);
                $asset->youtube_video_user_name($video->{author}->[0]->{name}->{'$t'});
                $asset->youtube_video_user_id($video->{author}->[0]->{'yt$userId'}->{'$t'});

                # save thumbnails
                my %thumbs =
                    map {
                        $_->{'yt$name'} => {
                            width  => $_->{width},
                            height => $_->{height},
                        }
                    }
                    grep {
                        $_->{'yt$name'} =~ /^(default|mqdefault|hqdefault)$/
                    }
                    @{$video->{'media$group'}->{'media$thumbnail'}};

                $asset->youtube_video_thumbnails(\%thumbs);

                # importing tags
                if (my $tags = $video->{'media$group'}->{'media$keywords'}->{'$t'}) {
                    $asset->set_tags( split(/\s*,\s*/, $tags) );
                }

                my $original = $asset->clone;
                $asset->save or return $app->error("Couldn't save asset: " . $asset->errstr);
                $app->run_callbacks('cms_post_save.asset', $app, $asset, $original);

                # be nice and return users back to asset insert/listing dialog views
                if ($params{continue_args}) {
                    my $url = $app->uri . '?' . $params{continue_args};
                    $url .= '&no_insert=' . $params{no_insert};
                    $url .= '&dialog_view=1';
                    return $app->redirect($url);
                }

                # otherwise close dialog via js and redirect to the normal
                # asset listing page (seems to be the default mt behavior)
                $params{new_asset_id} = $asset->id;
                $tmpl = plugin->load_tmpl('create_video_complete.tmpl');
            }
        }
    }

    %params = (%params, %errors, errors => 1) if keys %errors;
    $tmpl ||= plugin->load_tmpl("create_video.tmpl");
    return $app->build_page($tmpl, \%params);
}

sub asset_list_source {
    my ($cb, $app, $tmpl) = @_;

    if ($app->param('filter_val')) {
        if ($app->param('filter_val') eq 'youtube_video') {
            # fixing title
            my $replace_re = '<mt:setvarblock name="page_title">.*?setvarblock>';
            my $new = q{<mt:setvarblock name="page_title">Insert YouTube Video</mt:setvarblock>};
            $$tmpl =~ s/$replace_re/$new/;

            # replacing "Upload New File" with our thingy
            $replace_re = '<mt:setvarblock name="upload_new_file_link">.*?setvarblock>';
            # omg %)
            $new = <<NEW;
<mt:setvarblock name="upload_new_file_link">
<img src="<mt:var name="static_uri">images/status_icons/create.gif" alt="Add YouTube Video" width="9" height="9" />
<mt:unless name="asset_select"><mt:setvar name="entry_insert" value="1"></mt:unless>
<a href="<mt:var name="script_url">?__mode=youtube_video_create&amp;blog_id=<mt:var name="blog_id">&amp;no_insert=<mt:var name="no_insert">&amp;dialog_view=1&amp;<mt:if name="asset_select">asset_select=1&amp;<mt:else>entry_insert=1&amp;</mt:if>edit_field=<mt:var name="edit_field" escape="url">&amp;continue_args=<mt:var name="return_args" escape="url">">Add YouTube Video</a>
</mt:setvarblock>
NEW
            $$tmpl =~ s/$replace_re/$new/s;
            $$tmpl =~ s/phrase="Insert"/phrase="Continue"/;
        }
    }
    else {
        # just appending our "Add YouTube Video" link on listings with mixed asset types
        my $replace_re = '(<mt:setvarblock name="upload_new_file_link">.*?)(<\/mt:setvarblock>)';
        my $new = <<NEW;
<img src="<mt:var name="static_uri">images/status_icons/create.gif" alt="Add YouTube Video" width="9" height="9" style="margin-left: 1em" />
<a href="<mt:var name="script_url">?__mode=youtube_video_create&amp;blog_id=<mt:var name="blog_id">&amp;no_insert=<mt:var name="no_insert">&amp;dialog_view=1&amp;<mt:if name="asset_select">asset_select=1&amp;<mt:else>entry_insert=1&amp;</mt:if>edit_field=<mt:var name="edit_field" escape="url">&amp;continue_args=<mt:var name="return_args" escape="url">">Add YouTube Video</a>
NEW
        $$tmpl =~ s/$replace_re/$1$new$2/s;
    }
}

sub asset_insert_source {
    my ($cb, $app, $tmpl) = @_;

    # enable thumbnail previews for youtube videos in the entry asset manager
    my $old = '<mt:If tag="AssetType" like="\^\((.+?)\)\$">';
    my $new;
    $$tmpl =~ s/$old/<mt:If tag="AssetType" like="^($1|youtube video)\$">/g;

    $old = '<mt:If tag="AssetType" eq="image">';
    $new = '<mt:If tag="AssetType" like="^(image|youtube video)$">';
    $$tmpl =~ s/\Q$old\E/$new/g;
}

sub edit_entry_param {
    my ($cb, $app, $param, $tmpl) = @_;

    # enable thumbnail previews for youtube videos in the entry asset manager
    if (ref $param->{asset_loop}) {
        for my $p (@{$param->{asset_loop}}) {
            my $asset = MT::Asset->load($p->{asset_id});
            if ($asset->class eq 'youtube_video') {
                ($p->{asset_thumb}) = $asset->thumbnail_url(Width => 100);
            }
        }
    }
}

sub editor_source {
    my ($cb, $app, $tmpl) = @_;

    # adding some css
    $$tmpl .= q{
        <mt:setvarblock name="html_head" append="1">
        <link rel="stylesheet" type="text/css" href="<mt:var name="static_uri">plugins/YouTubeAssets/editor.css" />
        </mt:setvarblock>
    };

    # adding insert video toolbar button
    my $insert_image_button_re = '<a.*?<b>Insert Image<\/b>.*?<\/a>';
    my $new_button = '<a href="javascript: void 0;" title="Insert YouTube Video" mt:command="open-dialog" mt:dialog-params="__mode=list_assets&amp;_type=asset&amp;edit_field=<mt:var name="toolbar_edit_field">&amp;blog_id=<mt:var name="blog_id">&amp;dialog_view=1&amp;filter=class&amp;filter_val=youtube_video" class="command-insert-youtube-video toolbar button"><b>Insert YouTube Video</b><s></s></a>';
    $$tmpl =~ s/($insert_image_button_re)/$1$new_button/;
}

1;
