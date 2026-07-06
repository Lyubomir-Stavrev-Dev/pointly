#!/bin/bash
# Build, sign, and export a Mac App Store .pkg for Pointly, ready to upload
# to App Store Connect. Uses the Xcode archive flow (NOT the SwiftPM/Developer
# ID flow in release.sh, which is for direct distribution only).
#
# Prereqs:
#   - xcodegen installed            (brew install xcodegen)
#   - Signed into Xcode with the team (K62L488Y4H). Automatic signing will
#     fetch/create the "Apple Distribution" cert + Mac App Store profile.
set -e
cd "$(dirname "$0")"

SCHEME="Pointly"
ARCHIVE="build/Pointly.xcarchive"
EXPORT="build/appstore"

echo "==> Generating Xcode project from project.yml..."
xcodegen generate

echo "==> Archiving (Release, App Store signing)..."
xcodebuild -project Pointly.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

echo "==> Exporting App Store package..."
rm -rf "$EXPORT"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT" \
  -allowProvisioningUpdates

echo ""
echo "Done. Package: $EXPORT/Pointly.pkg"
echo ""
echo "Upload it with ONE of:"
echo "  - Transporter.app  (drag the .pkg in)"
echo "  - Xcode -> Organizer -> Distribute App"
echo "  - xcrun altool --upload-app -f \"$EXPORT/Pointly.pkg\" -t macos \\"
echo "      --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
