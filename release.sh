#!/bin/bash
# Build a notarized release zip ready for distribution.
set -e

cd "$(dirname "$0")"

IDENTITY="Developer ID Application: Lyubomir Stavrev (K62L488Y4H)"
PROFILE="pointly-notary"
ENTITLEMENTS="Pointly/Pointly.entitlements"
APP="Pointly.app"
ZIP="Pointly-release.zip"

echo "Building release..."
swift build -c release 2>&1 | tail -5

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

echo ""
echo "Done! Distribute: $ZIP"
