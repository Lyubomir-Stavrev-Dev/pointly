#!/bin/bash
# Build with swift build and update the .app bundle, then relaunch.
set -e

cd "$(dirname "$0")"

echo "Building..."
swift build 2>&1 | tail -5

BINARY=".build/arm64-apple-macosx/debug/Pointly"
APP_BINARY="Pointly.app/Contents/MacOS/Pointly"

cp "$BINARY" "$APP_BINARY"
echo "Binary updated."

# Kill existing instance
pkill -x Pointly 2>/dev/null || true
sleep 0.3

open Pointly.app
echo "Launched."

# To test first-launch onboarding, run:
#   defaults delete com.pointly.app hasSeenOnboarding
