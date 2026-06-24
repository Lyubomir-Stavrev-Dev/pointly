#!/bin/bash

echo "🔨 Creating macOS app bundle for Pointly..."

# Create the app bundle structure
APP_NAME="Pointly"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean up any existing bundle
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.pointly.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <false/>
    <key>CFBundleDisplayName</key>
    <string>Pointly</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# Build the Swift executable
echo "🔨 Building Swift executable..."
swift build -c release

# Copy the executable
if [ -f ".build/release/Pointly" ]; then
    cp ".build/release/Pointly" "$MACOS_DIR/$APP_NAME"
    chmod +x "$MACOS_DIR/$APP_NAME"
    echo "✅ Executable copied to app bundle"
else
    echo "❌ Build failed - no executable found"
    exit 1
fi

# Copy the app icon
echo "🎨 Copying app icon..."
ICNS_SRC="$(dirname "$0")/Pointly/Resources/AppIcon.icns"
if [ -f "$ICNS_SRC" ]; then
    cp "$ICNS_SRC" "$RESOURCES_DIR/AppIcon.icns"
    echo "✅ Icon copied"
else
    echo "⚠️  AppIcon.icns not found at $ICNS_SRC — skipping icon"
fi

echo "✅ App bundle created: $APP_BUNDLE"
echo "📱 You can now add this to Accessibility permissions!"
echo ""
echo "🔧 Next steps:"
echo "1. Go to System Settings > Privacy & Security > Accessibility"
echo "2. Click the + button"
echo "3. Navigate to this folder and select '$APP_BUNDLE'"
echo "4. Make sure it's enabled"
echo "5. Run: open $APP_BUNDLE"
echo ""
echo "🎯 Then try the hotkeys: ⌘⇧P, ⌘⌃P, ⌘⌥P, F10, F11, F12"

