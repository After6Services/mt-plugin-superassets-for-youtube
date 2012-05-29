# YouTube Assets

YouTube Assets is a Movable Type plugin that allows to import and use YouTube videos as native assets.

# Template Tags

## Overview

YouTube videos work just like other Movable Type's assets and can be accessed via tags *Asset*, *Assets*, *EntryAssets* and *PageAssets*:

    <mt:EntryAssets>
    <mt:if tag="AssetType" eq="youtube_video">
        <div>
        <strong><mt:AssetLabel escape="html"></strong>
        <p><mt:AssetDescription escape="html"></p>
        <img src="<mt:AssetThumbnailURL width="320">" width="320" height="180" alt="<mt:AssetLabel escape="html">" />
        </div>
    </mt:if>
    </mt:EntryAssets>

Videos can be filtered by class name:

    <mt:Assets class="youtube_video" lastn="1">
    ...
    </mt:Assets>

## Thumbnails

YouTube normally generates a few thumbnail images for each video, e.g.:

* 120x90px ("default")
* 320x180px ("mqdefault")
* 480x360px ("hqdefault")

The plugin provides access to YouTube video thumbnails through the standard tag *AssetThumbnailURL* and uses *width* and/or *height* tag attributes to find the best-matching image size available for the video:

        <img src="<mt:AssetThumbnailURL width="240">" width="240" alt="<mt:AssetLabel escape="html">" />

## Video Properties

There are a few extra asset properties accessible in templates:

* *youtube_video_id* - external video id
* *youtube_video_user_id* - external video owner's id
* *youtube_video_user_name* - external video owner's username

        <a href="http://www.youtube.com/watch?v=<mt:AssetProperty property="youtube_video_id">">

# Customizing default player

By default, the plugin renders a standard iframe-based version of the player for videos embedded into entries via the rich text editor. To customize the player, add a blog or system-level template module called "YouTube Player" with your code. The following template variables will be available:

* *width* - player's width selected on the embed options dialog window
* *height* - player's height
* *align* - player's text alignment ("none", "left", "center", "right")

The asset object and its blog will be available in the template context, so standard tags will work as well.
