#!/bin/bash

# Quick Test Script for Pointly Phase 2.1
# This script helps you quickly build and test the new features

set -e  # Exit on error

echo "🚀 Pointly Phase 2.1 - Quick Test Setup"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode not found. Please install Xcode to build Pointly.${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Checking project structure...${NC}"

# Verify key files exist
key_files=(
    "Pointly/Core/InteractionModeManager.swift"
    "Pointly/Core/Rendering/MetalRenderer.swift"
    "Pointly/Core/Rendering/Shaders/DrawingShaders.metal"
    "Pointly/State/DrawingState.swift"
    "Pointly/UI/FloatingToolbar.swift"
    "Pointly/UI/OverlayView.swift"
    "Pointly/AppDelegate.swift"
    "Pointly/PointlyApp.swift"
)

missing_files=0
for file in "${key_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Missing: $file${NC}"
        ((missing_files++))
    else
        echo -e "${GREEN}✅ Found: $file${NC}"
    fi
done

if [ $missing_files -gt 0 ]; then
    echo -e "${RED}❌ Missing $missing_files key files. Build may fail.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All key files present!${NC}"
echo ""

# Count Swift files
swift_count=$(find Pointly -name "*.swift" | wc -l)
echo -e "${BLUE}📊 Found $swift_count Swift files${NC}"

# Try to build
echo -e "${BLUE}🔨 Attempting to build...${NC}"

# Build for testing (Debug configuration)
if xcodebuild \
    -project Pointly.xcodeproj \
    -scheme Pointly \
    -configuration Debug \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    build > build_output.log 2>&1; then
    
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Show where the app is
    app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "Pointly.app" -type d 2>/dev/null | head -1)
    if [ -n "$app_path" ]; then
        echo -e "${BLUE}📱 App built at: $app_path${NC}"
        echo -e "${YELLOW}💡 You can run it from Xcode or double-click the app${NC}"
    fi
    
else
    echo -e "${RED}❌ Build failed. Checking for common issues...${NC}"
    
    # Show last few lines of build log
    echo -e "${YELLOW}📋 Last 10 lines of build output:${NC}"
    tail -10 build_output.log
    
    # Check for common issues
    if grep -q "Metal" build_output.log; then
        echo -e "${YELLOW}⚠️  Metal-related issue detected. This is usually okay - app will fall back to Core Graphics.${NC}"
    fi
    
    if grep -q "Signing" build_output.log; then
        echo -e "${YELLOW}⚠️  Code signing issue. Try running from Xcode directly.${NC}"
    fi
    
    exit 1
fi

echo ""
echo -e "${BLUE}🧪 Testing Instructions:${NC}"
echo "1. Open Pointly.xcodeproj in Xcode"
echo "2. Press ⌘R to run"
echo "3. Grant Screen Recording permission when prompted"
echo "4. Look for pencil icon in menu bar"
echo "5. Press ⌘⇧P to activate overlay"
echo ""
echo -e "${YELLOW}🔑 Key Features to Test:${NC}"
echo "• Press Tab to toggle Interact/Draw modes"
echo "• Try new tools: Marker, Laser Pointer, Blur Brush"
echo "• Check mode indicator appears when switching"
echo "• Verify smooth drawing performance"
echo ""
echo -e "${GREEN}🎯 Ready to test Phase 2.1 features!${NC}"

# Clean up
rm -f build_output.log
