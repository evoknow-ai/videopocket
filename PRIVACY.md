# VideoPocket Privacy Policy

Effective date: August 12, 2026

VideoPocket is published by EVOKNOW, Inc. It helps users save media they own or are authorized to download from supported X/Twitter, Facebook, and Instagram pages.

## Data collection

VideoPocket does not collect, sell, transmit, or share personal information, browsing history, authentication information, website content, or downloaded media with EVOKNOW, Inc. or any third-party analytics or advertising service.

## How data is processed

- The Chrome extension reads supported pages locally to locate media and its post URL, and downloads only after the user invokes VideoPocket.
- Direct media downloads are handled by Chrome's download manager.
- When required, the post URL and user-visible title are sent only to the VideoPocket Mac Helper at `127.0.0.1` on the user's own computer.
- Preferences and a legacy local-helper pairing token may be stored with `chrome.storage.local` on the user's device.
- VideoPocket checks a public JSON file in this GitHub repository for version updates. GitHub may process ordinary connection metadata under its own privacy policy.

## Local Mac Helper

The optional Mac Helper runs locally, accepts requests only on the loopback interface, and saves completed media under the user's Downloads folder. It does not upload media or account credentials to VideoPocket servers. VideoPocket does not operate a remote processing server.

## Retention and deletion

EVOKNOW, Inc. retains no user data because VideoPocket does not collect it. Users can remove locally stored extension preferences by uninstalling the extension or clearing its site data, and can delete downloaded files through Finder.

## Security and limitations

VideoPocket does not export browser cookies, bypass digital rights management, or support protected media. Users are responsible for downloading only content they created, own, or have permission to save, and for complying with applicable law and platform terms.

## Changes

Material changes will be published in this file and noted in the project changelog.

## Contact

Privacy questions may be submitted through the [VideoPocket GitHub issue tracker](https://github.com/evoknow-ai/videopocket/issues).
