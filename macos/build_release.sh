#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
MAC_DIR="$ROOT_DIR/macos"
BUILD_DIR="$ROOT_DIR/dist"
APP_NAME="VideoPocket Helper"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/VideoPocket-Mac-0.3.2.dmg"
IDENTITY="Developer ID Application: EVOKNOW, Inc (5R2X97DDYQ)"
NOTARY_PROFILE="VideoPocketNotary"

echo "Building VideoPocket Helper 0.3.2…"
security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null || { echo "Developer ID certificate not found."; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null || { echo "Notarization profile not available."; exit 1; }

if [[ -d "$BUILD_DIR" ]]; then rm -rf "$BUILD_DIR"; fi
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$MAC_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$MAC_DIR/install_helper.sh" "$APP_PATH/Contents/Resources/install_helper.sh"
cp "$ROOT_DIR/helper/videopocket_helper.py" "$APP_PATH/Contents/Resources/videopocket_helper.py"
cp "$ROOT_DIR/helper/com.videopocket.helper.plist.template" "$APP_PATH/Contents/Resources/com.videopocket.helper.plist.template"
chmod +x "$APP_PATH/Contents/Resources/install_helper.sh"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -parse-as-library -O -target arm64-apple-macos12.0 -sdk "$SDK_PATH" -framework AppKit -framework Foundation "$MAC_DIR/VideoPocketHelper.swift" -o "$BUILD_DIR/helper-arm64"
xcrun swiftc -parse-as-library -O -target x86_64-apple-macos12.0 -sdk "$SDK_PATH" -framework AppKit -framework Foundation "$MAC_DIR/VideoPocketHelper.swift" -o "$BUILD_DIR/helper-x86_64"
lipo -create "$BUILD_DIR/helper-arm64" "$BUILD_DIR/helper-x86_64" -output "$APP_PATH/Contents/MacOS/VideoPocketHelper"

ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
SOURCE_ICON="$ROOT_DIR/extension/icons/128.png"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  size="${spec%% *}"; name="${spec#* }"; sips -z "$size" "$size" "$SOURCE_ICON" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

codesign --force --deep --options runtime --timestamp --entitlements "$MAC_DIR/entitlements.plist" --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

DMG_STAGE="$BUILD_DIR/dmg"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "VideoPocket" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"

echo "Submitting to Apple for notarization…"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

echo ""
echo "Release ready: $DMG_PATH"
