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

# Recreate the bundle scaffolding if it doesn't exist (e.g. after a cleanup).
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ ! -f "$APP/Contents/Info.plist" ]; then
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>Pointly</string>
	<key>CFBundleIdentifier</key><string>com.pointly.macos</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>Pointly</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.3</string>
	<key>CFBundleVersion</key><string>5</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Pointly. All rights reserved.</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSScreenCaptureUsageDescription</key><string>Pointly needs screen recording permission for the Cut &amp; Move tool to capture and reposition annotations.</string>
	<key>ITSAppUsesNonExemptEncryption</key><false/>
</dict>
</plist>
PLIST
fi
echo "APPL????" > "$APP/Contents/PkgInfo"

cp "$BINARY" "$APP_BINARY"

if [ -d "$BUNDLE" ]; then
    cp -R "$BUNDLE" "$APP_RESOURCES/"
fi
cp "Pointly/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"

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
