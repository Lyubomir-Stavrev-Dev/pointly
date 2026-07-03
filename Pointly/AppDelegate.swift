import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindowManager: OverlayWindowManager?
    var globalHotkeyManager: GlobalHotkeyManager?
    private var mainHotkeyCode: UInt32 = 35
    private var mainHotkeyMods: NSEvent.ModifierFlags = [.command, .shift]
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.setup()

        NSApp.setActivationPolicy(.accessory)
        setupMenuBarItem()

        // NOTE: The Accessibility permission prompt is deliberately NOT shown at
        // launch — App Review dislikes permission requests before the user sees
        // why. It fires on first entry into interact mode instead, where the
        // global key monitor actually needs it (OverlayWindowManager).

        // Prevent macOS from restoring SwiftUI scene windows on future launches.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Close any visible SwiftUI scene windows (e.g. blank Settings) that macOS
        // restored from the previous session — only affects windows that are visible
        // and not ones we explicitly manage.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let ours = [self.onboardingWindow, self.settingsWindow].compactMap { $0 }
            for w in NSApp.windows where w.isVisible && !ours.contains(w) {
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
        reregisterAllHotkeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkeyChanged(_:)),
            name: .globalHotkeyChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToolBindingsChanged),
            name: .toolBindingsChanged,
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
            button.appearsDisabled = true   // app starts with overlay off
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Toggle Overlay (⌘⇧P)", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Whiteboard Canvas (⌘W)", action: #selector(toggleWhiteboardMode), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Keyboard Shortcuts...", action: #selector(openKeyboardShortcuts), keyEquivalent: ""))
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

    @objc private func toggleWhiteboardMode() {
        overlayWindowManager?.toggleWhiteboardMode()
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
        mainHotkeyCode = keyCode
        mainHotkeyMods = modifiers
        reregisterAllHotkeys()
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
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.contentView = FirstMouseHostingView(rootView: SettingsView())
            window.center()
            settingsWindow = window
        }
        // Lower canvas so Settings (at normal level) renders above it without blending issues
        overlayWindowManager?.lowerCanvasForPanel()
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: settingsWindow)
        NotificationCenter.default.addObserver(
            overlayWindowManager as Any,
            selector: #selector(OverlayWindowManager.restoreCanvasLevel),
            name: NSWindow.willCloseNotification,
            object: settingsWindow
        )
        settingsWindow?.level = .floating
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showTutorial() {
        onboardingWindow = nil  // force a fresh window each time
        showOnboarding(thenShowToolbar: false)
    }

    @objc private func openKeyboardShortcuts() {
        openSettings()
        // Small delay so SwiftUI has time to subscribe to the notification on first open
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .navigateToShortcuts, object: nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Hotkey Registration

    private func reregisterAllHotkeys() {
        globalHotkeyManager?.unregisterAll()
        globalHotkeyManager?.registerHotkey(keyCode: mainHotkeyCode, modifiers: mainHotkeyMods)
    }

    @objc private func handleToolBindingsChanged() {
        overlayWindowManager?.registerToolHotkeys()
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


// MARK: - Menu Bar Icon Updates

extension AppDelegate {
    @objc private func handleModeChange() {
        DispatchQueue.main.async { self.updateMenuBarIcon() }
    }

    // Always a pencil so the menu bar item stays recognizably Pointly:
    // filled = draw mode, outline = interact (pass-through), dimmed outline = overlay off.
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        if let mgr = overlayWindowManager, mgr.isActive {
            button.appearsDisabled = false
            switch mgr.currentInteractionMode?.currentMode {
            case .interact:
                button.image = NSImage(systemSymbolName: "pencil.circle",
                                       accessibilityDescription: "Pointly - Interact Mode")
            default:
                button.image = NSImage(systemSymbolName: "pencil.circle.fill",
                                       accessibilityDescription: "Pointly - Draw Mode")
            }
        } else {
            button.image = NSImage(systemSymbolName: "pencil.circle",
                                   accessibilityDescription: "Pointly - Inactive")
            button.appearsDisabled = true
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let selectTool = Notification.Name("SelectTool")
}
