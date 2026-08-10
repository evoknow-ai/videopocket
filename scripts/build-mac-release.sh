#!/bin/bash
set -Eeuo pipefail

VERSION="${1:-0.4.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: EVOKNOW, Inc (5R2X97DDYQ)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-VideoPocketNotary}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/macos"
DIST_DIR="$ROOT_DIR/dist"
VENV_DIR="$BUILD_DIR/venv"
APP_NAME="VideoPocket Helper"
APP_PATH="$BUILD_DIR/app/$APP_NAME.app"
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

YT_DLP_MAIN="$("$VENV_DIR/bin/python" - <<'PY'
import pathlib, yt_dlp
print(pathlib.Path(yt_dlp.__file__).with_name("__main__.py"))
PY
)"
FFMPEG_BIN="$("$VENV_DIR/bin/python" - <<'PY'
import imageio_ffmpeg
print(imageio_ffmpeg.get_ffmpeg_exe())
PY
)"

"$VENV_DIR/bin/pyinstaller" --noconfirm --clean --windowed --onedir   --name "$APP_NAME"   "$ROOT_DIR/helper/videopocket_helper.py"

"$VENV_DIR/bin/pyinstaller" --noconfirm --clean --onefile   --name yt-dlp --collect-all yt_dlp "$YT_DLP_MAIN"

cp -R "$BUILD_DIR/pyinstaller-dist/$APP_NAME.app" "$APP_PATH"
mkdir -p "$APP_PATH/Contents/Resources/bin"
cp "$BUILD_DIR/pyinstaller-dist/yt-dlp" "$APP_PATH/Contents/Resources/bin/yt-dlp"
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
</dict></plist>
PLIST

while IFS= read -r -d '' item; do
  codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$item"
done < <(find "$APP_PATH/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' \) -print0)

codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS"   --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

STAGE_DIR="$BUILD_DIR/dmg"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
cp -R "$ROOT_DIR/extension" "$STAGE_DIR/VideoPocket Extension"
ln -s /Applications "$STAGE_DIR/Applications"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/extension" "$ZIP_PATH"

hdiutil create -volname "VideoPocket $VERSION" -srcfolder "$STAGE_DIR"   -ov -format UDZO "$DMG_PATH"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

printf '\nRelease ready:\n  %s\n  %s\n' "$DMG_PATH" "$ZIP_PATH"
