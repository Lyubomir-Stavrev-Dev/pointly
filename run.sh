#!/bin/bash
# Build with swift build and update the .app bundle, then relaunch.
set -e

cd "$(dirname "$0")"

echo "Building..."
swift build 2>&1 | tail -5

BINARY=".build/arm64-apple-macosx/debug/Pointly"
BUNDLE=".build/arm64-apple-macosx/debug/Pointly_Pointly.bundle"
APP_BINARY="Pointly.app/Contents/MacOS/Pointly"
APP_RESOURCES="Pointly.app/Contents/Resources"

# Recreate bundle structure if it was deleted
mkdir -p "Pointly.app/Contents/MacOS"
mkdir -p "Pointly.app/Contents/Resources"
# Write Info.plist with resolved values (no Xcode variables)
cat > "Pointly.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>Pointly</string>
	<key>CFBundleIdentifier</key><string>com.pointly.macos</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>Pointly</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.3</string>
	<key>CFBundleVersion</key><string>5</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHumanReadableCopyright</key><string>Copyright © 2024 Pointly. All rights reserved.</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSScreenCaptureUsageDescription</key><string>Pointly needs screen recording permission for the Cut &amp; Move tool to capture and reposition annotations.</string>
	<key>ITSAppUsesNonExemptEncryption</key><false/>
</dict>
</plist>
PLIST

cp "$BINARY" "$APP_BINARY"

# Copy SwiftPM resource bundle (Metal shaders, asset catalog) into the app
if [ -d "$BUNDLE" ]; then
    cp -R "$BUNDLE" "$APP_RESOURCES/"
fi

codesign --force --deep --sign - --entitlements "Pointly/Pointly.entitlements" "Pointly.app"
echo "Binary updated."

# Kill existing instance
pkill -x Pointly 2>/dev/null || true
sleep 0.3

open Pointly.app
echo "Launched."

# To test first-launch onboarding, run:
#   defaults delete com.pointly.macos hasSeenOnboarding
