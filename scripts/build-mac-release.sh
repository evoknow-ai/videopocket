#!/bin/bash
set -Eeuo pipefail

VERSION="${1:-0.4.5}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: EVOKNOW, Inc (5R2X97DDYQ)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-VideoPocketNotary}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/macos"
DIST_DIR="$ROOT_DIR/dist"
VENV_DIR="$BUILD_DIR/venv"
APP_NAME="VideoPocket Helper"
APP_PATH="$BUILD_DIR/app/$APP_NAME.app"
INSTALLER_NAME="Install VideoPocket"
INSTALLER_PATH="$BUILD_DIR/installer/$INSTALLER_NAME.app"
DMG_PATH="$DIST_DIR/VideoPocket-Mac-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/VideoPocket-Extension-$VERSION.zip"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

[[ "$(uname -s)" == "Darwin" ]] || fail "Run this release build on macOS."
[[ -f "$ROOT_DIR/helper/videopocket_helper.py" ]] || fail "Run from the VideoPocket repository."
need python3
need xcrun
need codesign
need hdiutil
need ditto
need iconutil
need sips
security find-identity -v -p codesigning | grep -F "$SIGN_IDENTITY" >/dev/null ||
  fail "Developer ID certificate not found: $SIGN_IDENTITY"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null ||
  fail "Notary profile unavailable. Create it with: xcrun notarytool store-credentials $NOTARY_PROFILE"

SOURCE_VERSION="$(sed -n 's/^VERSION = "\([^"]*\)"/\1/p' "$ROOT_DIR/helper/videopocket_helper.py")"
[[ "$SOURCE_VERSION" == "$VERSION" ]] ||
  fail "Requested $VERSION, but helper source reports $SOURCE_VERSION."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/app" "$DIST_DIR"
rm -f "$DMG_PATH" "$ZIP_PATH"

python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install "pyinstaller>=6,<7" "yt-dlp" "imageio-ffmpeg"

FFMPEG_BIN="$("$VENV_DIR/bin/python" - <<'PY'
import imageio_ffmpeg
print(imageio_ffmpeg.get_ffmpeg_exe())
PY
)"

"$VENV_DIR/bin/pyinstaller" --noconfirm --clean --windowed --onedir \
  --distpath "$BUILD_DIR/pyinstaller-dist" --workpath "$BUILD_DIR/pyinstaller-work/helper" \
  --specpath "$BUILD_DIR" --name "$APP_NAME" --collect-all yt_dlp \
  "$ROOT_DIR/helper/videopocket_helper.py"

cp -R "$BUILD_DIR/pyinstaller-dist/$APP_NAME.app" "$APP_PATH"
mkdir -p "$APP_PATH/Contents/Resources/bin"
cp "$FFMPEG_BIN" "$APP_PATH/Contents/Resources/bin/ffmpeg"
chmod 755 "$APP_PATH/Contents/Resources/bin/"*

plutil -replace CFBundleIdentifier -string "us.eatsleepai.videopocket.helper" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace LSUIElement -bool YES "$APP_PATH/Contents/Info.plist"

ENTITLEMENTS="$BUILD_DIR/entitlements.plist"
cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
PLIST

while IFS= read -r -d '' item; do
  if file "$item" | grep -q 'Mach-O'; then
    codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS" \
      --sign "$SIGN_IDENTITY" "$item"
  fi
done < <(find "$APP_PATH/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' \) -print0)

codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Build a separate native installer. It owns the replacement flow so the
# always-running Helper never has to replace itself in Finder.
mkdir -p "$INSTALLER_PATH/Contents/MacOS" "$INSTALLER_PATH/Contents/Resources"
INSTALLER_ARM64="$BUILD_DIR/installer-arm64"
INSTALLER_X86_64="$BUILD_DIR/installer-x86_64"
xcrun swiftc -parse-as-library -O -target arm64-apple-macos12 \
  "$ROOT_DIR/macos/VideoPocketInstaller.swift" -o "$INSTALLER_ARM64"
xcrun swiftc -parse-as-library -O -target x86_64-apple-macos12 \
  "$ROOT_DIR/macos/VideoPocketInstaller.swift" -o "$INSTALLER_X86_64"
lipo -create "$INSTALLER_ARM64" "$INSTALLER_X86_64" \
  -output "$INSTALLER_PATH/Contents/MacOS/$INSTALLER_NAME"
cp "$ROOT_DIR/macos/Installer-Info.plist" "$INSTALLER_PATH/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$INSTALLER_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$INSTALLER_PATH/Contents/Info.plist"
ICONSET="$BUILD_DIR/VideoPocket.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT_DIR/extension/icons/128.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ROOT_DIR/extension/icons/128.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$INSTALLER_PATH/Contents/Resources/VideoPocket.icns"
mkdir -p "$INSTALLER_PATH/Contents/Resources/Payload"
cp -R "$APP_PATH" "$INSTALLER_PATH/Contents/Resources/Payload/"
codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$INSTALLER_PATH"
codesign --verify --deep --strict --verbose=2 "$INSTALLER_PATH"

STAGE_DIR="$BUILD_DIR/dmg"
mkdir -p "$STAGE_DIR"
cp -R "$INSTALLER_PATH" "$STAGE_DIR/"
cp -R "$ROOT_DIR/extension" "$STAGE_DIR/VideoPocket Extension"
cp "$ROOT_DIR/macos/INSTALL.txt" "$STAGE_DIR/Read Me.txt"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/extension" "$ZIP_PATH"

hdiutil create -volname "VideoPocket $VERSION" -srcfolder "$STAGE_DIR"   -ov -format UDZO "$DMG_PATH"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

printf '\nRelease ready:\n  %s\n  %s\n' "$DMG_PATH" "$ZIP_PATH"
