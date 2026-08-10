# VideoPocket

A private Chrome extension that saves videos you own or have permission to download from X, Facebook, Instagram, LinkedIn, and YouTube. Direct MP4 files download in Chrome. Segmented streams are handed to an optional local Mac helper and never sent to a third-party service.

**Imagined by Mohammed Kabir. Developed by his agents.**

[Kabir's website](https://eatsleepai.us) · [Changelog](CHANGELOG.md) · [GitHub](https://github.com/evoknow-ai/videopocket)

## Install the Chrome extension

1. Unzip `VideoPocket.zip`.
2. Open `chrome://extensions` in Chrome.
3. Enable **Developer mode**.
4. Click **Load unpacked** and select the `VideoPocket/extension` folder.
5. Open a supported site. A **Save video** button appears over each detected video.

## Install the Mac helper

The helper improves Facebook, Instagram, X and YouTube support by combining separate audio and video streams into an MP4.

1. Open the signed and notarized VideoPocket DMG.
2. Double-click **Install VideoPocket**.
3. Click **Install**. The installer safely closes any older Helper, replaces it in Applications, and starts the new version.

That is all. The Chrome extension pairs automatically. Python, yt-dlp, and FFmpeg are bundled, so users do not need Terminal, Homebrew, or a separate runtime.

Downloads are saved under `~/Downloads/VideoPocket`. Change this in `helper/config.json` after its first launch.

Completed downloads are normalized to H.264 video and AAC audio. Rotation is applied to the pixels and cleared from the metadata for reliable playback in QuickTime, Finder, browsers, and mobile devices.

## Privacy and security

- There is no remote VideoPocket server.
- The helper listens only on `127.0.0.1` and requires a random token.
- Only an allowlist of supported HTTPS domains is accepted.
- Playlists are disabled to prevent accidental bulk downloads.
- Browser cookies are not exported to the helper in this version.

## Known limitations

- Sites frequently change their markup and delivery systems, so adapters will occasionally need updating.
- Private or age-restricted media may not download because browser cookies are intentionally not copied.
- DRM-protected video is not supported.
- Chrome Web Store distribution may be restricted; this project is intended for private, unpacked installation.
- You are responsible for complying with copyright law and each platform's terms.

## Troubleshooting

- **Helper offline:** double-click `helper/Install VideoPocket.command` and reload the extension.
- **Direct download fails:** install/start the helper so VideoPocket can use the post URL.
- **No button:** reload the page after installing the extension and start playback once.
- Logs are written to `helper/helper.log` and `/tmp/videopocket-helper.err`.

## Credits

VideoPocket was imagined by Mohammed Kabir and developed by his agents. Released under the MIT License.
