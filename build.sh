#!/bin/bash

# Comprehensive build script for Pointly
# This will build the Xcode project and create a distributable app

set -e  # Exit on any error

echo "🚀 Building Pointly..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Pointly"
SCHEME_NAME="Pointly"
CONFIGURATION="Release"
BUILD_DIR="build"

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode build tools not found. Please install Xcode.${NC}"
    exit 1
fi

# Build the project
echo -e "${BLUE}🔨 Building $PROJECT_NAME...${NC}"
xcodebuild \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Copy the app to build directory
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$PROJECT_NAME.app"
if [ -d "$APP_PATH" ]; then
    cp -R "$APP_PATH" "$BUILD_DIR/"
    echo -e "${GREEN}📦 App copied to $BUILD_DIR/$PROJECT_NAME.app${NC}"
else
    echo -e "${RED}❌ Could not find built app at $APP_PATH${NC}"
    exit 1
fi

# Run tests if available
echo -e "${BLUE}🧪 Running tests...${NC}"
xcodebuild \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "Debug" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    test || echo -e "${YELLOW}⚠️  Tests failed or not available${NC}"

# Create DMG for distribution
echo -e "${BLUE}💿 Creating DMG...${NC}"
DMG_NAME="$PROJECT_NAME-$(date +%Y%m%d)"
mkdir -p "$BUILD_DIR/dmg-temp"
cp -R "$BUILD_DIR/$PROJECT_NAME.app" "$BUILD_DIR/dmg-temp/"

# Create Applications symlink
ln -s /Applications "$BUILD_DIR/dmg-temp/Applications"

# Create DMG
hdiutil create \
    -volname "$PROJECT_NAME" \
    -srcfolder "$BUILD_DIR/dmg-temp" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME.dmg"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG created: $BUILD_DIR/$DMG_NAME.dmg${NC}"
else
    echo -e "${YELLOW}⚠️  DMG creation failed${NC}"
fi

# Cleanup
rm -rf "$BUILD_DIR/dmg-temp"
rm -rf "$BUILD_DIR/DerivedData"

echo -e "${GREEN}🎉 Build complete!${NC}"
echo -e "${BLUE}📁 Output directory: $BUILD_DIR${NC}"
echo -e "${BLUE}🚀 App bundle: $BUILD_DIR/$PROJECT_NAME.app${NC}"
echo -e "${BLUE}💿 DMG installer: $BUILD_DIR/$DMG_NAME.dmg${NC}"

# Show file sizes
echo -e "${BLUE}📊 Build summary:${NC}"
du -sh "$BUILD_DIR/$PROJECT_NAME.app" 2>/dev/null || echo "App size: Unknown"
du -sh "$BUILD_DIR/$DMG_NAME.dmg" 2>/dev/null || echo "DMG size: Unknown"
