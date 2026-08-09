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

### Signed DMG release

Public releases use `VideoPocket-Mac-0.3.2.dmg`. Open the DMG, drag **VideoPocket Helper** to Applications, launch it, and click **Install Helper**. The application pairs with Chrome automatically.

Maintainers with the EVOKNOW Developer ID certificate and `VideoPocketNotary` Keychain profile can build, sign, notarize, staple, and verify the DMG with:

```bash
./macos/build_release.sh
```

The completed DMG appears under `dist/`.

Downloads are organized automatically by source, for example:

```text
~/Downloads/VideoPocket/downloads/x/2026-08-09-account-123456789.mp4
~/Downloads/VideoPocket/downloads/fb/2026-08-09-account-987654321.mp4
```

### Source installer fallback

1. Open the `helper` folder.
2. Control-click or right-click **Install VideoPocket.command**, choose **Open**, then confirm **Open**. This first-launch step is required because the current installer is not yet Apple-notarized.
3. Wait for the **VideoPocket is ready** notification.

That is all. The Chrome extension pairs automatically. The installer keeps the helper under `~/Library/Application Support/VideoPocket`, so deleting or replacing the downloaded ZIP will no longer break it. It also starts automatically at login.

Homebrew must already be installed. The installer automatically adds FFmpeg when needed and keeps Python packages inside VideoPocket's private environment.

### Why macOS shows a security warning

The current community build is not signed with an Apple Developer ID or notarized by Apple. Opening it through Finder's **Open** context-menu action records your explicit approval. A warning-free public installer requires Apple Developer Program credentials and a signed, notarized release build.

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
