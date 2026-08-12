# Changelog

## 0.4.6 - 2026-08-12

- Prepared the extension for Chrome Web Store review.
- Reduced site access to X/Twitter, Facebook, and Instagram.
- Removed LinkedIn and YouTube permissions and code paths from the store submission.
- Added a public privacy policy, permission audit, reviewer instructions, finalized listing copy, and store artwork.

## 0.4.5 - 2026-08-11

- Added Instagram image downloads alongside existing Instagram Reel and video support.
- Added **Save image** controls to eligible Instagram post and carousel images.
- Preserved JPG, PNG, and WebP file types and organized direct downloads by source.
- Added the VideoPocket project icon to the native macOS installer.

## 0.4.4 - 2026-08-11

- Added live download, merge, and QuickTime-conversion progress in the extension popup.
- Kept incomplete work behind a progress state until the final MP4 is ready.
- Added an **Update available** notice with release and changelog links.
- Added a toolbar badge when either the extension or Mac Helper is behind the current release.

## 0.4.3 - 2026-08-11

- Replaced the blocking installer alert with a responsive native progress window.
- Added visible stages for preparation, old-Helper shutdown, application copying, and startup.
- Added clear in-window completion and actionable error states.
- Forced final videos to QuickTime-compatible H.264 video and AAC audio, with hardware and software encoder fallbacks.

## 0.4.2 - 2026-08-11

- Added a **Downloads** button that opens VideoPocket's configured download folder in Finder.
- Added an **Errors** panel that displays the latest helper log inside the extension popup.
- Reworded queued-download messages so they no longer imply that a file was successfully saved.

## 0.4.1 - 2026-08-10

- Added a native **Install VideoPocket** app to the DMG.
- Automatically quits and replaces an older Helper before installation.
- Automatically launches the newly installed Helper.
- Corrected hardened-runtime signing for the bundled Python and downloader components.
- Added library-validation entitlements required by the bundled PyInstaller runtime.

## 0.4.0 - 2026-08-10

- Removed token pairing as a requirement for current extension-to-Helper requests.
- Kept automatic token repair for compatibility with older Helpers.
- Separated Helper health detection from authentication so pairing errors no longer appear as “Helper offline.”
- Increased the connection timeout from 0.9 seconds to 3 seconds.
- Added a one-click **Try again** action in the extension popup.
- Added Helper version reporting without exposing its token.
- Stopped printing the security token in the Helper window and during initialization.

## 0.2.1 - 2026-08-08

- Added the Credits & About page.
- Added project attribution, Eat Sleep AI, changelog, and GitHub links.
- Prepared the complete public GitHub repository.
