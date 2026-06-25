import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindowManager: OverlayWindowManager?
    var globalHotkeyManager: GlobalHotkeyManager?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var modeMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.setup()

        NSApp.setActivationPolicy(.accessory)
        setupMenuBarItem()

        // Always close any SwiftUI scene windows (e.g. blank Settings) that macOS
        // may restore or show on activation — our own windows are opened explicitly below.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for w in NSApp.windows where w !== self.onboardingWindow
                                      && w !== self.settingsWindow {
                w.orderOut(nil)
            }
        }

        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        if isFirstLaunch {
            showOnboarding()
        }

        overlayWindowManager = OverlayWindowManager()

        if !isFirstLaunch {
            if UserDefaults.standard.object(forKey: "showToolbarOnStartup") as? Bool ?? false {
                overlayWindowManager?.toggleOverlay()
            }
            let startupBehavior = UserDefaults.standard.string(forKey: "startupBehavior") ?? "menubar"
            if startupBehavior != "hidden" {
                NSApp.activate(ignoringOtherApps: false)
            }
        }

        globalHotkeyManager = GlobalHotkeyManager()
        globalHotkeyManager?.delegate = self

        globalHotkeyManager?.registerHotkey(
            keyCode: 35, // P key
            modifiers: [.command, .shift]
        )
        // Tab is NOT registered globally — it would break every other app.
        // Tab mode-toggle is handled by OverlayView.onKeyPress when the overlay has focus.

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkeyChanged(_:)),
            name: .globalHotkeyChanged,
            object: nil
        )

        // Menu bar icon updates (was in awakeFromNib, which never fires for @NSApplicationDelegateAdaptor)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModeChange),
            name: .updateMenuBarIcon,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModeChange),
            name: .interactionModeChanged,
            object: nil
        )

    }

    // MARK: - Menu Bar Setup

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Pointly")
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(NSMenuItem(title: "Toggle Overlay (⌘⇧P)", action: #selector(toggleOverlay), keyEquivalent: ""))

        let modeItem = NSMenuItem(title: "Toggle Mode (Tab)", action: #selector(toggleInteractionMode), keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)
        modeMenuItem = modeItem

        menu.addItem(NSMenuItem.separator())

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
        menu.addItem(NSMenuItem(title: "Show Tutorial", action: #selector(showTutorial), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Pointly", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func statusItemClicked() {}

    @objc private func toggleOverlay() {
        guard let mgr = overlayWindowManager else { return }
        // If overlay is up and in interact mode, switch back to draw instead of hiding.
        if mgr.isActive, mgr.currentInteractionMode?.currentMode == .interact {
            mgr.currentInteractionMode?.switchTo(mode: .draw)
        } else {
            mgr.toggleOverlay()
        }
    }

    @objc private func toggleInteractionMode() {
        overlayWindowManager?.currentInteractionMode?.toggleMode()
    }

    @objc private func handleHotkeyChanged(_ notification: Notification) {
        guard let hotkeyString = notification.object as? String else { return }
        var modifiers: NSEvent.ModifierFlags = []
        var keyChar = ""
        for char in hotkeyString {
            switch char {
            case "⌘": modifiers.insert(.command)
            case "⇧": modifiers.insert(.shift)
            case "⌥": modifiers.insert(.option)
            case "⌃": modifiers.insert(.control)
            default: keyChar = String(char)
            }
        }
        guard !keyChar.isEmpty,
              let keyCode = GlobalHotkeyManager.keyCode(for: keyChar) else { return }
        globalHotkeyManager?.unregisterAll()
        globalHotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
        // Tab is intentionally NOT re-registered as a global hotkey.
    }

    private func showOnboarding(thenShowToolbar: Bool = true) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.contentView = FirstMouseHostingView(rootView: OnboardingView {
            self.onboardingWindow?.orderOut(nil)
            if thenShowToolbar {
                self.overlayWindowManager?.toggleOverlay()
            }
        })
        window.center()
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.contentView = FirstMouseHostingView(rootView: SettingsView())
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showTutorial() {
        onboardingWindow = nil  // force a fresh window each time
        showOnboarding(thenShowToolbar: false)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Tool Selection

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
        toggleOverlay()  // already contains interact-mode → draw logic
    }
}

// MARK: - NSMenuDelegate — update mode item enabled state when menu opens

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        modeMenuItem?.isEnabled = overlayWindowManager?.isActive ?? false
    }
}

// MARK: - Menu Bar Icon Updates

extension AppDelegate {
    @objc private func handleModeChange() {
        DispatchQueue.main.async { self.updateMenuBarIcon() }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        if let mgr = overlayWindowManager, mgr.isActive {
            switch mgr.currentInteractionMode?.currentMode {
            case .draw:
                button.image = NSImage(systemSymbolName: "pencil.circle.fill",
                                       accessibilityDescription: "Pointly - Draw Mode")
            case .interact:
                button.image = NSImage(systemSymbolName: "hand.point.up.left.fill",
                                       accessibilityDescription: "Pointly - Interact Mode")
            default:
                button.image = NSImage(systemSymbolName: "pencil.circle.fill",
                                       accessibilityDescription: "Pointly - Active")
            }
        } else {
            button.image = NSImage(systemSymbolName: "pencil.circle",
                                   accessibilityDescription: "Pointly - Inactive")
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let selectTool = Notification.Name("SelectTool")
}
