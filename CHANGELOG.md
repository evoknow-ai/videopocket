# Changelog

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
