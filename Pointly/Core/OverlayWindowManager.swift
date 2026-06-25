import AppKit
import SwiftUI
import CoreGraphics
import Combine

class OverlayWindowManager: ObservableObject {
    private var canvasWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var toolbarPanel: NSPanel?
    private var paywallPanel: NSPanel?
    private var blurPanel: NSPanel?
    private var blurNSView: BlurOverlayNSView?
    private var isOverlayActive = false
    private var colorPanelObserver: NSKeyValueObservation?
    private var keyMonitor: Any?
    private var toolCancellable: AnyCancellable?
    private var elementsCancellable: AnyCancellable?

    let sharedDrawingState    = DrawingState()
    let sharedInteractionMode = InteractionModeManager()

    init() {
        buildCanvasWindows(for: NSScreen.screens)
        buildToolbarPanel()
        buildBlurPanel()
        installKeyMonitor()
        installToolObserver()
        installElementsObserver()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyModeToWindows),
            name: .interactionModeChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyToolbarTheme),
            name: .toolbarThemeChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowPaywall(_:)),
            name: .showPaywall, object: nil)
    }

    // MARK: - Canvas windows (one per screen, drawing surface only)

    private func buildCanvasWindows(for screens: [NSScreen]) {
        for screen in screens {
            let id = displayID(for: screen)
            guard id != 0, canvasWindows[id] == nil else { continue }
            canvasWindows[id] = makeCanvasWindow(for: screen)
        }
    }

    private func makeCanvasWindow(for screen: NSScreen) -> NSWindow {
        let win = CanvasWindow(contentRect: screen.frame,
                               styleMask: [.borderless, .fullSizeContentView],
                               backing: .buffered, defer: false)
        win.level              = .screenSaver
        win.backgroundColor    = .clear
        win.isOpaque           = false
        win.hasShadow          = false
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentView = NSHostingView(rootView:
            OverlayView(drawingState: sharedDrawingState,
                        interactionMode: sharedInteractionMode))
        win.orderOut(nil)
        return win
    }

    // MARK: - Screen blur panel
    //
    // A separate NSPanel that lives *between* normal app windows (level 0) and the
    // canvas (level .screenSaver). Its NSVisualEffectView uses .behindWindow blending
    // so it blurs the apps below it. A CAShapeLayer mask restricts the blur to exactly
    // where the user has painted with the Screen Blur tool.

    private func buildBlurPanel() {
        guard let screen = NSScreen.main else { return }
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Level 1: above normal apps (0), well below canvas (.screenSaver = 1000)
        panel.level              = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.hasShadow          = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let blurView = BlurOverlayNSView()
        panel.contentView = blurView
        blurNSView   = blurView
        blurPanel    = panel
        panel.orderOut(nil)
    }

    private func installElementsObserver() {
        elementsCancellable = sharedDrawingState.$elements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elements in
                guard let self else { return }
                let h = self.blurPanel?.frame.height ?? (NSScreen.main?.frame.height ?? 800)
                self.blurNSView?.update(elements: elements, canvasHeight: h)
            }
    }

    // MARK: - Cursor tool pass-through observer

    private func installToolObserver() {
        toolCancellable = sharedDrawingState.$selectedTool
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tool in
                self?.applyModeToWindows()
                if tool == .cursor { NSCursor.arrow.set() }
            }
    }

    // MARK: - Global key monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOverlayActive else { return event }
            let ds = self.sharedDrawingState
            let im = self.sharedInteractionMode

            switch event.keyCode {
            case 51, 117: // ⌫ backspace (51) or ⌦ forward delete (117)
                if ds.selectedTool == .select && !ds.selectedElementIDs.isEmpty {
                    DispatchQueue.main.async { ds.deleteSelected() }
                    return nil
                }

            case 53: // Escape
                if ds.isTextInputActive {
                    NotificationCenter.default.post(name: .cancelTextInput, object: nil)
                } else {
                    DispatchQueue.main.async { im.toggleMode() }
                }
                return nil

            default:
                break
            }
            return event
        }
    }

    // MARK: - Toolbar panel
    //
    // A small NSPanel sized to exactly fit the toolbar pill.
    // Because it never covers the canvas drawing area, returning nil from hitTest
    // would only affect the tiny toolbar frame — but we avoid that entirely by
    // keeping the panel tight via the onSizeChange callback.
    //
    // The panel is ALWAYS ignoresMouseEvents = false (interactive), even in interact
    // mode, so the user can tap "Draw" to switch back without a keyboard shortcut.
    // Only the canvas windows are toggled for mode changes.

    private func buildToolbarPanel() {
        guard let screen = NSScreen.main else { return }
        let initialSize = CGSize(width: 72, height: 380)
        let origin = CGPoint(
            x: 20,
            y: screen.frame.midY - initialSize.height / 2
        )
        let panel = ToolbarPanel(
            contentRect: NSRect(origin: origin, size: initialSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level              = .init(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.hasShadow          = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable          = true   // lets performDrag work
        panel.hidesOnDeactivate  = false  // stay visible when another app gets focus
        let hostingView = FirstMouseHostingView(rootView:
            ToolbarPanelView(
                drawingState: sharedDrawingState,
                interactionMode: sharedInteractionMode,
                onSizeChange: { [weak self, weak panel] size in
                    self?.fitPanel(panel, to: size)
                },
                onClose: { [weak self] in
                    self?.toggleOverlay()
                }
            ))
        panel.contentView = hostingView
        panel.orderOut(nil)
        toolbarPanel = panel
        applyToolbarTheme()
    }

    // Resize the panel to exactly wrap the toolbar content (no empty transparent area).
    // Guard against no-op resizes — unnecessary setFrame calls steal focus mid-click.
    private func fitPanel(_ panel: NSPanel?, to size: CGSize) {
        guard let panel else { return }
        let newH = ceil(size.height)
        let newW = ceil(size.width)
        guard panel.frame.size.width != newW || panel.frame.size.height != newH else { return }
        DispatchQueue.main.async {
            var frame = panel.frame
            frame.origin.y += frame.height - newH
            frame.size = CGSize(width: newW, height: newH)
            panel.setFrame(frame, display: true)
        }
    }

    // MARK: - Toolbar theme

    @objc func applyToolbarTheme() {
        let theme = UserDefaults.standard.string(forKey: "toolbarTheme") ?? "system"
        let appearance: NSAppearance? = switch theme {
        case "light": NSAppearance(named: .aqua)
        case "dark":  NSAppearance(named: .darkAqua)
        default:      nil  // nil = follow system
        }
        toolbarPanel?.appearance = appearance
    }

    // MARK: - Screen changes

    @objc private func appDidResignActive() {
        guard isOverlayActive else { return }
        toolbarPanel?.orderFrontRegardless()
    }

    @objc private func screensChanged() {
        let liveIDs = Set(NSScreen.screens.map { displayID(for: $0) })
        for id in Set(canvasWindows.keys).subtracting(liveIDs) {
            canvasWindows[id]?.orderOut(nil)
            canvasWindows.removeValue(forKey: id)
        }
        buildCanvasWindows(for: NSScreen.screens)
        if isOverlayActive { showAll() }
    }

    // MARK: - Mode → window sync
    //
    // In interact mode canvas windows become fully transparent to mouse events.
    // The toolbar panel is NEVER toggled — it stays clickable so the user can
    // tap "Draw" (or any tool) to switch back without needing a keyboard shortcut.

    @objc private func applyModeToWindows() {
        let isInteract = sharedInteractionMode.currentMode == .interact
        let isCursor   = sharedDrawingState.selectedTool == .cursor
        let passThrough = isInteract || isCursor
        for win in canvasWindows.values {
            win.ignoresMouseEvents = passThrough
            win.level = passThrough ? .floating : .screenSaver
        }
        if !passThrough {
            let mainID = displayID(for: NSScreen.main ?? NSScreen.screens[0])
            canvasWindows[mainID]?.makeKey()
        }
    }

    // MARK: - Show / Hide

    func toggleOverlay() {
        if isOverlayActive { hideAll() } else { showAll() }
        isOverlayActive.toggle()
    }

    private func showAll() {
        requestScreenRecordingPermission()
        // Blur panel first so canvas and toolbar sit on top
        if let screen = NSScreen.main {
            blurPanel?.setFrame(screen.frame, display: true)
        }
        blurPanel?.orderFrontRegardless()
        for (id, win) in canvasWindows {
            if let s = screen(for: id) { win.setFrame(s.frame, display: true) }
            win.orderFrontRegardless()
        }
        toolbarPanel?.orderFrontRegardless()

        // Pre-elevate the color panel so it sits above the canvas and is
        // immediately interactive when the ColorPicker opens it. Also watch
        // for isVisible changes in case SwiftUI re-orders the panel on open.
        let colorLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        NSColorPanel.shared.level = colorLevel
        colorPanelObserver = NSColorPanel.shared.observe(\.isVisible, options: [.new]) { panel, change in
            guard change.newValue == true else { return }
            DispatchQueue.main.async {
                panel.level = colorLevel
                panel.orderFrontRegardless()
            }
        }

        applyModeToWindows()
        let mainID = displayID(for: NSScreen.main ?? NSScreen.screens[0])
        canvasWindows[mainID]?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideAll() {
        canvasWindows.values.forEach { $0.orderOut(nil) }
        toolbarPanel?.orderOut(nil)
        paywallPanel?.orderOut(nil)
        blurPanel?.orderOut(nil)
        colorPanelObserver = nil
        NSColorPanel.shared.level = .floating
    }

    // MARK: - Paywall

    @objc private func handleShowPaywall(_ notification: Notification) {
        guard let tool = notification.object as? DrawingTool else { return }
        showPaywall(for: tool)
    }

    func showPaywall(for tool: DrawingTool) {
        paywallPanel?.orderOut(nil)

        let size = CGSize(width: 400, height: 560)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 3)

        panel.contentView = FirstMouseHostingView(rootView:
            ProPaywallView(tool: tool, proManager: .shared) { [weak self, weak panel] in
                panel?.orderOut(nil)
                self?.paywallPanel = nil
                // Re-focus canvas if overlay is active
                if self?.isOverlayActive == true {
                    let mainID = self?.displayID(for: NSScreen.main ?? NSScreen.screens[0]) ?? 0
                    self?.canvasWindows[mainID]?.makeKey()
                }
            }
        )
        panel.center()
        paywallPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Screen recording permission

    private func requestScreenRecordingPermission() {
        guard CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) == nil else { return }
        let alert = NSAlert()
        alert.messageText     = "Screen Recording Permission Required"
        alert.informativeText = "Pointly needs screen recording permission in System Settings › Privacy & Security › Screen Recording."
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Helpers

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }
    private func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { displayID(for: $0) == id }
    }

    var currentInteractionMode: InteractionModeManager? { sharedInteractionMode }
    var isActive: Bool { isOverlayActive }
}

// MARK: - ToolbarPanel
// canBecomeKey = false prevents focus stealing from the canvas window.
// No .nonactivatingPanel style mask — that flag was blocking SwiftUI's ColorPicker
// from opening the color panel on the first click.

private final class ToolbarPanel: NSPanel {
    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - CanvasWindow
// canBecomeKey = true so SwiftUI onKeyPress fires for Tab / Escape mode switching.
// sendEvent intercepts mouse events that land over NSColorPanel and re-routes them
// directly to the panel — no z-level juggling required.

private final class CanvasWindow: NSWindow {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        let mouseTypes: [NSEvent.EventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .scrollWheel, .mouseMoved
        ]
        let panel = NSColorPanel.shared
        if panel.isVisible, mouseTypes.contains(event.type) {
            // Convert the event's window-local point to screen coords, then check
            // whether it falls inside the color panel.
            let screenPt = convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)).origin
            if panel.frame.contains(screenPt) {
                // Re-create the event with coordinates in the panel's space and
                // forward it, suppressing the original so nothing is drawn.
                let panelPt = panel.convertFromScreen(
                    NSRect(origin: screenPt, size: .zero)).origin
                if let fwd = NSEvent.mouseEvent(
                    with: event.type,
                    location: panelPt,
                    modifierFlags: event.modifierFlags,
                    timestamp: event.timestamp,
                    windowNumber: panel.windowNumber,
                    context: nil,
                    eventNumber: event.eventNumber,
                    clickCount: event.clickCount,
                    pressure: event.pressure
                ) {
                    panel.sendEvent(fwd)
                }
                return  // do NOT call super — canvas must not draw
            }
        }
        super.sendEvent(event)
    }
}

// MARK: - FirstMouseHostingView
// Overrides acceptsFirstMouse so toolbar buttons fire on the very first click,
// even when the app is not the active application or the panel is not key.
// Without this, NSHostingView consumes the first click just to activate, and
// the user has to click every button twice.

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
