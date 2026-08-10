# Mac distribution

The repository owns the complete macOS release process. Terminal history is never required.

## What the release builder produces

- A self-contained **VideoPocket Helper.app** with its own Python runtime, yt-dlp, and FFmpeg.
- A signed and notarized `VideoPocket-Mac-<version>.dmg`.
- A matching `VideoPocket-Extension-<version>.zip`.
- Persistent configuration and logs under `~/Library/Application Support/VideoPocket`.

## One-time Mac setup

You need:

1. Xcode Command Line Tools.
2. A **Developer ID Application** certificate installed in Keychain.
3. A notarization profile stored once in Keychain:

```bash
xcrun notarytool store-credentials VideoPocketNotary
```

The default signing identity is:

```text
Developer ID Application: EVOKNOW, Inc (5R2X97DDYQ)
```

Neither Apple credentials nor certificates are stored in this repository.

## Build, sign, and notarize a release

From the repository root:

```bash
bash scripts/build-mac-release.sh 0.4.0
```

The script performs preflight checks before modifying build output. It then creates an isolated Python environment, packages all runtime dependencies, signs nested executables and the app with hardened runtime, builds and signs the DMG, waits for Apple notarization, staples the ticket, and runs final Gatekeeper verification.

Completed files are placed in `dist/`.

## Optional overrides

If the certificate or Keychain profile changes:

```bash
SIGN_IDENTITY="Developer ID Application: Company Name (TEAMID)" \
NOTARY_PROFILE="DifferentNotaryProfile" \
bash scripts/build-mac-release.sh 0.4.0
```

## Release checklist

1. Update the version in `helper/videopocket_helper.py` and `extension/manifest.json`.
2. Update `CHANGELOG.md`.
3. Commit the release source.
4. Run the builder with the same version.
5. Test the DMG on a Mac that does not have the source checkout.
6. Upload the DMG and extension ZIP to the matching GitHub release.

The builder stops if its requested version does not match the Helper source version.
