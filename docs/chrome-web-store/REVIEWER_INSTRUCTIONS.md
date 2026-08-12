# Chrome Web Store Reviewer Instructions

## Product setup

VideoPocket 0.4.6 is a macOS companion extension. No account, password, payment, or special test credentials are required.

1. Install the signed and notarized `VideoPocket-Mac-0.4.6.dmg` from the v0.4.6 GitHub Release.
2. Double-click **Install VideoPocket** and wait for the success message.
3. Install the submitted Chrome extension package.
4. Open a public post containing media on X/Twitter, Facebook, or Instagram.
5. Click the overlaid **Save video** or **Save image** button, or click the extension icon and choose **Save video on this page**.
6. Open the extension popup to observe Downloading, Merging, Converting, and Ready status.
7. Click **Downloads** to open `~/Downloads/VideoPocket`.

## Suggested public test cases

Use any public, non-DRM post controlled by the reviewer or content the reviewer is authorized to save. Instagram supports Reels, video posts, single-image posts, and carousel images.

## Expected behavior

- Direct media is saved through Chrome.
- Segmented media is passed to the local Helper at `127.0.0.1:17839` for local merging and conversion.
- Final video output is H.264/AAC MP4 for QuickTime compatibility.
- Media is organized into `x`, `fb`, or `ig` folders.
- No media, cookies, or browsing data is sent to EVOKNOW, Inc.

## Intentional limitations

- VideoPocket supports only X/Twitter, Facebook, and Instagram.
- It does not support YouTube, LinkedIn, DRM-protected media, private media requiring exported cookies, or bulk playlist downloads.
- Users are instructed to save only media they own or have permission to download.

## Support

Repository and releases: https://github.com/evoknow-ai/videopocket

Privacy policy: https://github.com/evoknow-ai/videopocket/blob/main/PRIVACY.md
