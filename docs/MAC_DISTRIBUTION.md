# Mac distribution

The source installer works today, but public distribution should move to a signed and notarized `.app` or `.pkg`.

## Current installation

Control-click **Install VideoPocket.command**, choose **Open**, then confirm **Open**. This is the standard explicit-approval path for an unsigned community script.

## Production release requirements

1. Enroll the publisher in the Apple Developer Program.
2. Create a Developer ID Application certificate.
3. Package the helper and its runtime dependencies into a versioned `.app`.
4. Sign nested executables and the outer application with hardened runtime enabled.
5. Submit the archive to Apple's notary service with `notarytool`.
6. Staple the successful notarization ticket.
7. Distribute the notarized application in a signed DMG.

The Chrome extension can continue pairing with the same localhost helper API after the packaging changes.
