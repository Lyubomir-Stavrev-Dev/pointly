import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindowManager: OverlayWindowManager?
    var globalHotkeyManager: GlobalHotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we'll use menubar only
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        setupMenuBarItem()
        
        // Initialize overlay manager
        overlayWindowManager = OverlayWindowManager()
        
        // Setup global hotkey manager
        globalHotkeyManager = GlobalHotkeyManager()
        globalHotkeyManager?.delegate = self
        
        // Register default hotkey (⌘⇧P) for overlay toggle
        globalHotkeyManager?.registerHotkey(
            keyCode: 35, // P key
            modifiers: [.command, .shift]
        )
        
        // Register Tab key for interaction mode toggle
        globalHotkeyManager?.registerHotkey(
            keyCode: 48, // Tab key
            modifiers: []
        ) { [weak self] in
            self?.toggleInteractionMode()
        }
    }
    
    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Pointly")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        
        // Overlay controls
        menu.addItem(NSMenuItem(title: "Toggle Overlay (⌘⇧P)", action: #selector(toggleOverlay), keyEquivalent: ""))
        
        // Mode controls (only when overlay is active)
        let modeItem = NSMenuItem(title: "Toggle Mode (Tab)", action: #selector(toggleInteractionMode), keyEquivalent: "")
        modeItem.isEnabled = overlayWindowManager?.isActive ?? false
        menu.addItem(modeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Tool shortcuts submenu
        let toolsSubmenu = NSMenu()
        toolsSubmenu.addItem(NSMenuItem(title: "Pen (1)", action: #selector(selectPenTool), keyEquivalent: "1"))
        toolsSubmenu.addItem(NSMenuItem(title: "Highlighter (2)", action: #selector(selectHighlighterTool), keyEquivalent: "2"))
        toolsSubmenu.addItem(NSMenuItem(title: "Marker (3)", action: #selector(selectMarkerTool), keyEquivalent: "3"))
        toolsSubmenu.addItem(NSMenuItem(title: "Laser Pointer (4)", action: #selector(selectLaserTool), keyEquivalent: "4"))
        toolsSubmenu.addItem(NSMenuItem(title: "Eraser (E)", action: #selector(selectEraserTool), keyEquivalent: "e"))
        
        let toolsMenuItem = NSMenuItem(title: "Tools", action: nil, keyEquivalent: "")
        toolsMenuItem.submenu = toolsSubmenu
        menu.addItem(toolsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Pointly", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func statusItemClicked() {
        // Handle status item click
    }
    
    @objc private func toggleOverlay() {
        overlayWindowManager?.toggleOverlay()
    }
    
    @objc private func toggleInteractionMode() {
        // Toggle interaction mode if overlay is active
        if let modeManager = overlayWindowManager?.currentInteractionMode {
            modeManager.toggleMode()
        }
    }
    
    @objc private func openSettings() {
        // Open settings window
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Pointly Settings"
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Tool Selection Actions
    
    @objc private func selectPenTool() {
        NotificationCenter.default.post(name: .selectTool, object: DrawingTool.pen)
    }
    
    @objc private func selectHighlighterTool() {
        NotificationCenter.default.post(name: .selectTool, object: DrawingTool.highlighter)
    }
    
    @objc private func selectMarkerTool() {
        NotificationCenter.default.post(name: .selectTool, object: DrawingTool.marker)
    }
    
    @objc private func selectLaserTool() {
        NotificationCenter.default.post(name: .selectTool, object: DrawingTool.laserPointer)
    }
    
    @objc private func selectEraserTool() {
        NotificationCenter.default.post(name: .selectTool, object: DrawingTool.eraser)
    }
}

// MARK: - GlobalHotkeyManagerDelegate
extension AppDelegate: GlobalHotkeyManagerDelegate {
    func hotkeyPressed() {
        toggleOverlay()
    }
}

// MARK: - Menu Bar Updates

extension AppDelegate {
    
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        
        // Update icon based on overlay state and interaction mode
        if let overlayManager = overlayWindowManager, overlayManager.isActive {
            if let modeManager = overlayManager.currentInteractionMode {
                switch modeManager.currentMode {
                case .draw:
                    button.image = NSImage(systemSymbolName: "pencil.circle.fill", accessibilityDescription: "Pointly - Draw Mode")
                case .interact:
                    button.image = NSImage(systemSymbolName: "hand.point.up.left.fill", accessibilityDescription: "Pointly - Interact Mode")
                }
            } else {
                button.image = NSImage(systemSymbolName: "pencil.circle.fill", accessibilityDescription: "Pointly - Active")
            }
        } else {
            button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Pointly - Inactive")
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Listen for mode changes to update menu bar icon
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModeChange),
            name: .updateMenuBarIcon,
            object: nil
        )
    }
    
    @objc private func handleModeChange() {
        DispatchQueue.main.async {
            self.updateMenuBarIcon()
        }
    }
}

// MARK: - Additional Notifications

extension Notification.Name {
    /// Posted when a tool should be selected
    static let selectTool = Notification.Name("SelectTool")
}
