import SwiftUI
import AppKit

@main
struct PointlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindowManager: OverlayWindowManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we'll use menubar only
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        setupMenuBarItem()
        
        // Initialize overlay manager
        overlayWindowManager = OverlayWindowManager()
        
        // Setup global hotkey
        setupGlobalHotkey()
    }
    
    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Pointly")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Pointly", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupGlobalHotkey() {
        // TODO: Implement global hotkey registration
        // This will use Carbon or modern alternatives for hotkey detection
    }
    
    @objc private func statusItemClicked() {
        // Handle status item click
    }
    
    @objc private func toggleOverlay() {
        overlayWindowManager?.toggleOverlay()
    }
    
    @objc private func openSettings() {
        // TODO: Show settings window
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
