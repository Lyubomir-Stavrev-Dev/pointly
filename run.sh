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
#   defaults delete com.pointly.app hasSeenOnboarding
