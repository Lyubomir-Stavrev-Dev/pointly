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
    private var upgradeMenuItems: [NSMenuItem] = []
    private var menuBarHintPopover: NSPopover?
    private var widgetPopover: NSPopover?
    private var contextMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.setup()

        // Before anything reads UserDefaults — DrawingState/AppDelegate use raw
        // reads, so intended defaults must be registered process-wide up front.
        SettingsStore.registerDefaults()

        NSApp.setActivationPolicy(.accessory)

        // Prevent macOS from restoring SwiftUI scene windows on future launches.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Close any visible SwiftUI scene windows (e.g. blank Settings) that macOS
        // restored from the previous session. Runs synchronously BEFORE the status
        // item or any of our own windows exist — the old delayed sweep could hide
        // the just-shown startup overlay (and, on some macOS versions, the status
        // item's own window).
        for w in NSApp.windows where w.isVisible {
            w.orderOut(nil)
        }

        setupMenuBarItem()

        // NOTE: The Accessibility permission prompt is deliberately NOT shown at
        // launch — App Review dislikes permission requests before the user sees
        // why. It fires on first entry into interact mode instead, where the
        // global key monitor actually needs it (OverlayWindowManager).

        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        if isFirstLaunch {
            showOnboarding()
        }

        overlayWindowManager = OverlayWindowManager()

        #if DEBUG
        // Dev-only, for paywall/spin-wheel styling and tests:
        // defaults write com.pointly.macos debugShowPaywallOnLaunch -bool true
        if UserDefaults.standard.bool(forKey: "debugShowPaywallOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NotificationCenter.default.post(name: .showPaywallForPlan, object: ProPlan.lifetime)
            }
        }
        // defaults write com.pointly.macos debugShowUpdateCardOnLaunch -bool true
        if UserDefaults.standard.bool(forKey: "debugShowUpdateCardOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UpdateChecker.showPreview()
            }
        }
        #endif

        if !isFirstLaunch {
            if UserDefaults.standard.object(forKey: "showToolbarOnStartup") as? Bool ?? false {
                overlayWindowManager?.toggleOverlay()
            }
            let startupBehavior = UserDefaults.standard.string(forKey: "startupBehavior") ?? "menubar"
            if startupBehavior != "hidden" {
                NSApp.activate(ignoringOtherApps: false)
            }
        }

        UpdateChecker.checkOnLaunch()

        globalHotkeyManager = GlobalHotkeyManager()
        globalHotkeyManager?.delegate = self
        // Honor a custom toggle hotkey saved in Settings (otherwise ⌘⇧P default)
        if let saved = UserDefaults.standard.string(forKey: "globalHotkey") {
            applyMainHotkeyString(saved)
        }
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        // Force-show even if a previous launch persisted a hidden state (happens on
        // notched Macs when the menu bar overflows, or if the user ever dragged the
        // item off). This app is menu-bar-only, so the item must never stay hidden.
        item.isVisible = true
        item.behavior = []

        if let button = item.button {
            button.image = menuBarImage(named: "pencil.circle")
            button.imagePosition = .imageOnly
            button.toolTip = "Pointly — Click to open, right-click for more"
            button.appearsDisabled = true
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Right-click context menu (power users / keyboard fallback)
        let upgradeSep   = NSMenuItem.separator()
        let goProItem    = NSMenuItem(title: "Upgrade to Pro…",      action: #selector(buyPro),     keyEquivalent: "")
        let goProPlusItem = NSMenuItem(title: "Get Pro+ (Lifetime)…", action: #selector(buyProPlus), keyEquivalent: "")
        upgradeMenuItems = [upgradeSep, goProItem, goProPlusItem]

        contextMenu.addItem(NSMenuItem(title: "Toggle Overlay (⌘⇧P)",  action: #selector(toggleOverlay),        keyEquivalent: ""))
        contextMenu.addItem(upgradeSep)
        contextMenu.addItem(goProItem)
        contextMenu.addItem(goProPlusItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Settings…",             action: #selector(openSettings),          keyEquivalent: ","))
        contextMenu.addItem(NSMenuItem(title: "Keyboard Shortcuts…",   action: #selector(openKeyboardShortcuts), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem(title: "Show Tutorial",         action: #selector(showTutorial),          keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit Pointly",          action: #selector(quitApp),               keyEquivalent: "q"))
        contextMenu.delegate = self
    }

    // Always returns a non-nil template image so the variable-length status item
    // can never collapse to zero width (invisible) if an SF Symbol is unavailable.
    private func menuBarImage(named name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15.5, weight: .semibold)
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "Pointly")?
                        .withSymbolConfiguration(config) {
            img.isTemplate = true
            return img
        }
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.labelColor.setStroke()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            path.lineWidth = 1.5
            path.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }

    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem?.menu = contextMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleWidgetPopover()
        }
    }

    private func toggleWidgetPopover() {
        guard let button = statusItem?.button else { return }
        if let pop = widgetPopover, pop.isShown {
            pop.close()
            return
        }
        if widgetPopover == nil {
            let pop = NSPopover()
            pop.contentViewController = NSHostingController(rootView: MenuBarWidgetView(
                onToggleOverlay:     { [weak self] in pop.close(); self?.toggleOverlay() },
                onCanvas:            { [weak self] in pop.close(); self?.toggleWhiteboardMode() },
                onTimer:             { [weak self] in pop.close(); self?.toggleTimer() },
                onCues:              { [weak self] in pop.close(); self?.toggleCues() },
                onZoom:              { [weak self] in pop.close(); self?.toggleZoom() },
                onSettings:          { [weak self] in pop.close(); self?.openSettings() },
                onKeyboardShortcuts: { [weak self] in pop.close(); self?.openKeyboardShortcuts() },
                onTutorial:          { [weak self] in pop.close(); self?.showTutorial() },
                onQuit:              { [weak self] in self?.quitApp() }
            ))
            pop.contentSize = NSSize(width: 270, height: 330)
            pop.behavior = .transient
            pop.animates = true
            pop.appearance = NSAppearance(named: .darkAqua)
            widgetPopover = pop
        }
        widgetPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

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

    @objc private func toggleTimer() {
        overlayWindowManager?.toggleTimerPanel()
    }

    @objc private func toggleCues() {
        overlayWindowManager?.togglePresenterCues()
    }

    @objc private func toggleZoom() {
        overlayWindowManager?.togglePresenterZoom()
    }

    @objc private func handleHotkeyChanged(_ notification: Notification) {
        guard let hotkeyString = notification.object as? String else { return }
        applyMainHotkeyString(hotkeyString)
        reregisterAllHotkeys()
    }

    private func applyMainHotkeyString(_ hotkeyString: String) {
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
        window.delegate = self   // red close button must still complete onboarding
        window.contentView = FirstMouseHostingView(rootView: OnboardingView(onDismiss: {
            self.onboardingWindow?.orderOut(nil)
            if thenShowToolbar {
                self.overlayWindowManager?.toggleOverlay()
            }
            // One-time menu bar hint so users discover the status icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                self.showMenuBarHint()
            }
        }, onContinueFree: {
            // User skipped purchasing — show spin-wheel welcome offer if eligible.
            // Small delay so the onboarding window has time to order out first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.overlayWindowManager?.maybeShowSpinWheel()
            }
        }))
        window.center()
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        openSettingsWindow(initialTab: .general)
    }

    private func openSettingsWindow(initialTab: SettingsTab) {
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
            window.contentView = FirstMouseHostingView(rootView: SettingsView(initialTab: initialTab))
            window.center()
            settingsWindow = window
            // Register once at creation — the old per-open add (with a remove
            // that targeted the wrong observer object) stacked duplicates.
            NotificationCenter.default.addObserver(
                overlayWindowManager as Any,
                selector: #selector(OverlayWindowManager.restoreCanvasLevel),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
        // Lower canvas so Settings (at normal level) renders above it without blending issues
        overlayWindowManager?.lowerCanvasForPanel()
        settingsWindow?.level = .floating
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showTutorial() {
        onboardingWindow?.orderOut(nil)   // don't orphan a visible window (its
        onboardingWindow = nil            // dismiss closure would hide the new one)
        showOnboarding(thenShowToolbar: false)
    }

    @objc private func openKeyboardShortcuts() {
        if settingsWindow == nil {
            // First open: pass the tab directly — a delayed notification raced
            // SwiftUI's subscription and could land on the default tab.
            openSettingsWindow(initialTab: .shortcuts)
        } else {
            openSettings()
            NotificationCenter.default.post(name: .navigateToShortcuts, object: nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func buyPro() {
        NotificationCenter.default.post(name: .showPaywallForPlan, object: ProPlan.annual)
    }

    @objc private func buyProPlus() {
        NotificationCenter.default.post(name: .showPaywallForPlan, object: ProPlan.lifetime)
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

// MARK: - NSWindowDelegate (onboarding close button)

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === onboardingWindow else { return }
        // The red close button bypasses OnboardingView's buttons — without
        // this, first-run users who close the window get onboarding again on
        // every launch and (LSUIElement, no Dock icon) an app that looks dead.
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showMenuBarHint()
        }
    }
}


// MARK: - Menu Bar Icon Updates

extension AppDelegate {
    @objc private func handleModeChange() {
        DispatchQueue.main.async {
            self.updateMenuBarIcon()
            MenuBarState.shared.isOverlayActive = self.overlayWindowManager?.isActive ?? false
        }
    }

    // Always a pencil so the menu bar item stays recognizably Pointly:
    // filled = draw mode, outline = interact (pass-through), dimmed outline = overlay off.
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        statusItem?.isVisible = true   // keep enforcing visibility on every state change
        if let mgr = overlayWindowManager, mgr.isActive {
            button.appearsDisabled = false
            switch mgr.currentInteractionMode?.currentMode {
            case .interact:
                button.image = menuBarImage(named: "pencil.circle")
            default:
                button.image = menuBarImage(named: "pencil.circle.fill")
            }
        } else {
            button.image = menuBarImage(named: "pencil.circle")
            button.appearsDisabled = true
        }
    }
}

// MARK: - Menu Bar Hint Popover

extension AppDelegate {
    func showMenuBarHint() {
        guard !UserDefaults.standard.bool(forKey: "menuBarHintShown") else { return }
        guard let button = statusItem?.button else { return }
        UserDefaults.standard.set(true, forKey: "menuBarHintShown")

        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: MenuBarHintView())
        popover.contentSize = NSSize(width: 272, height: 64)
        popover.behavior = .transient
        popover.animates = true
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        menuBarHintPopover = popover

        // Auto-dismiss after 6 seconds in case the user doesn't click anywhere
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.menuBarHintPopover?.close()
            self?.menuBarHintPopover = nil
        }
    }
}

// MARK: - Menu delegate (hide upgrade items once the user is Pro)

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        let isPro = ProManager.shared.isPro
        upgradeMenuItems.forEach { $0.isHidden = isPro }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let selectTool = Notification.Name("SelectTool")
}
