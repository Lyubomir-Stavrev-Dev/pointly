#!/bin/bash

# Create a proper Xcode project for Pointly
# This script creates a working macOS app project

echo "🛠️  Creating Xcode project for Pointly..."

# Create the Xcode project using the command line
# This is the most reliable way to create a proper project structure

cat > create_project.swift << 'EOF'
import Foundation

// Simple script to create basic project structure
print("Creating Xcode project structure...")

// We'll use a Package.swift approach which is more reliable
EOF

# Create Package.swift for Swift Package Manager approach
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pointly",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pointly", targets: ["Pointly"])
    ],
    targets: [
        .executableTarget(
            name: "Pointly",
            dependencies: [],
            path: "Sources",
            sources: [
                "main.swift"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
EOF

# Create Sources directory and move files
echo "📁 Organizing source files..."

mkdir -p Sources/Pointly
mkdir -p Sources/Resources

# Create a simplified main.swift that imports our modules
cat > Sources/main.swift << 'EOF'
import AppKit
import SwiftUI

@main
struct PointlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Simple AppDelegate for testing
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Pointly Phase 2.1 - Test Version Started!")
        print("📱 Look for the menu bar icon")
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create simple menu bar item
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Pointly")
            button.action = #selector(statusClicked)
            button.target = self
        }
    }
    
    @objc func statusClicked() {
        let alert = NSAlert()
        alert.messageText = "Pointly Phase 2.1 Test"
        alert.informativeText = "Basic app structure is working! Ready to integrate full features."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
EOF

echo "✅ Created Swift Package structure"
echo ""
echo "🧪 To test the basic structure:"
echo "1. swift run"
echo "   OR"
echo "2. open Package.swift in Xcode"
echo "3. Press ⌘R to run"
echo ""
echo "📝 This creates a minimal test version to verify the setup works."
echo "   Once this runs, we can integrate the full Phase 2.1 features."
