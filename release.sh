#!/bin/bash
# Build a notarized release zip ready for distribution.
set -e

cd "$(dirname "$0")"

IDENTITY="Developer ID Application: Lyubomir Stavrev (K62L488Y4H)"
PROFILE="pointly-notary"
ENTITLEMENTS="Pointly/Pointly.entitlements"
APP="Pointly.app"
ZIP="Pointly-release.zip"

echo "Building release (direct-distribution: license-key unlock enabled)..."
swift build -c release -Xswiftc -DDIRECT_BUILD 2>&1 | tail -5

BINARY=".build/arm64-apple-macosx/release/Pointly"
BUNDLE=".build/arm64-apple-macosx/release/Pointly_Pointly.bundle"
APP_BINARY="$APP/Contents/MacOS/Pointly"
APP_RESOURCES="$APP/Contents/Resources"

cp "$BINARY" "$APP_BINARY"

if [ -d "$BUNDLE" ]; then
    cp -R "$BUNDLE" "$APP_RESOURCES/"
fi

echo "Signing with Developer ID..."
codesign --force --deep --options runtime \
  --sign "$IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP"

echo "Creating zip..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP" \
  --keychain-profile "$PROFILE" \
  --wait

echo "Stapling..."
xcrun stapler staple "$APP"

echo "Re-zipping with stapled app..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Creating DMG for website distribution..."
DMG="website/downloads/Pointly.dmg"
mkdir -p website/downloads
rm -f "$DMG"
DMGDIR=$(mktemp -d)
cp -R "$APP" "$DMGDIR/"
ln -s /Applications "$DMGDIR/Applications"
hdiutil create -volname "Pointly" -srcfolder "$DMGDIR" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DMGDIR"
codesign --force --sign "$IDENTITY" "$DMG"

echo ""
echo "Done! Distribute: $ZIP  and  $DMG (deploy website/ to publish)"
