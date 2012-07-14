# YouTube Assets

YouTube Assets is a Movable Type plugin that allows users to import and use YouTube videos as assets in the Movable Type Asset Manager.  It is part of the SuperAssets series of plugins from After6 Services LLC.

# Installation

After downloading and uncompressing this package:

1. Upload the entire YouTubeAssets directory within the plugins directory of this distribution to the corresponding plugins directory within the Movable Type installation directory.
    * UNIX example:
        * Copy mt-plugin-youtube-assets/plugins/YouTubeAssets/ into /var/wwww/cgi-bin/mt/plugins/.
    * Windows example:
        * Copy mt-plugin-youtube-assets/plugins/YouTubeAssets/ into C:\webroot\mt-cgi\plugins\ .
2. Upload the entire YouTubeAssets directory within the mt-static directory of this distribution to the corresponding mt-static/plugins directory that your instance of Movable Type is configured to use.  Refer to the StaticWebPath configuration directive within your mt-config.cgi file for the location of the mt-static directory.
    * UNIX example: If the StaticWebPath configuration directive in mt-config.cgi is: **StaticWebPath  /var/www/html/mt-static/**,
        * Copy mt-plugin-youtube-assets/mt-static/plugins/YouTubeAssets/ into /var/www/html/mt-static/plugins/.
    * Windows example: If the StaticWebPath configuration directive in mt-config.cgi is: **StaticWebPath D:/htdocs/mt-static/**,
        * Copy mt-plugin-youtube-assets/mt-static/plugins/YouTubeAssets/ into D:/htdocs/mt-static/.

# Configuration

No configuration is required.

# Usage

## Template Tags

### Overview

YouTube videos work just like other Movable Type's assets and can be accessed via tags *Asset*, *Assets*, *EntryAssets* and *PageAssets*:

    <mt:EntryAssets>
    <mt:if tag="AssetType" eq="youtube video">
        <div>
        <strong><mt:AssetLabel escape="html"></strong>
        <p><mt:AssetDescription escape="html"></p>
        <img src="<mt:AssetThumbnailURL width="320">" width="320" height="180" alt="<mt:AssetLabel escape="html">" />
        </div>
    </mt:if>
    </mt:EntryAssets>

Videos can be filtered by class name:

    <mt:Assets type="youtube_video" lastn="1">
    ...
    </mt:Assets>

### Thumbnails
YouTube normally generates a few thumbnail images for each video, e.g.:

* 120x90px ("default")
* 320x180px ("mqdefault")
* 480x360px ("hqdefault")

The plugin provides access to YouTube video thumbnails through the standard tag *AssetThumbnailURL* and uses *width* and/or *height* tag attributes to find the best-matching image size available for the video:

        <img src="<mt:AssetThumbnailURL width="240">" width="240" alt="<mt:AssetLabel escape="html">" />

### Video Properties

There are a few extra asset properties accessible in templates:

* *youtube_video_id* - external video id
* *youtube_video_user_id* - external video owner's id
* *youtube_video_user_name* - external video owner's username

        <a href="http://www.youtube.com/watch?v=<mt:AssetProperty property="youtube_video_id">">

## Customizing default player

By default, the plugin renders a standard iframe-based version of the player for videos embedded into entries via the rich text editor. To customize the player, add a blog or system-level template module called "YouTube Player" with your code. The following template variables will be available:

* *width* - player's width selected on the embed options dialog window
* *height* - player's height
* *align* - player's text alignment ("none", "left", "center", "right")

The asset object and its blog will be available in the template context, so standard tags will work as well.

# Support

This plugin has not been tested with any version of Movable Type prior to Movable Type 4.38.

Although After6 Services LLC has developed this plugin, After6 only provides support for this plugin as part of a Movable Type support agreement that references this plugin by name.

# License

This plugin is licensed under The BSD 2-Clause License, http://www.opensource.org/licenses/bsd-license.php.  See LICENSE.md for the exact license.

# Authorship

YouTube Assets was originally written by Arseni Mouchinski with help from Dave Aiello and Jeremy King.

# Copyright

Copyright &copy; 2012, After6 Services LLC.  All Rights Reserved.

YouTube is a registered trademark of YouTube LLC.

SuperAssets is a trademark of After6 Services LLC.

Movable Type is a registered trademark of Six Apart Limited.

Trademarks, product names, company names, or logos used in connection with this repository are the property of their respective owners and references do not imply any endorsement, sponsorship, or affiliation with After6 Services LLC unless otherwise specified.
