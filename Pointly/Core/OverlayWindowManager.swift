import AppKit
import SwiftUI
import CoreGraphics
import Combine
import ScreenCaptureKit

class OverlayWindowManager: ObservableObject {
    private var canvasWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var toolbarPanel: NSPanel?
    private var paywallPanel: NSPanel?
    private var liftedCaptures: [(panel: NSPanel, coverID: UUID)] = []
    private var isOverlayActive = false
    private var colorPanelObserver: NSKeyValueObservation?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var globalDrawKeyMonitor: Any?
    private var toolCancellable: AnyCancellable?
    private let toolHotkeyManager = GlobalHotkeyManager()

    let sharedDrawingState    = DrawingState()
    let sharedInteractionMode = InteractionModeManager()

    init() {
        buildCanvasWindows(for: NSScreen.screens)
        buildToolbarPanel()
        installKeyMonitor()
        installToolObserver()

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
            self, selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowPaywall(_:)),
            name: .showPaywall, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleShowPaywallForPlan(_:)),
            name: .showPaywallForPlan, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCaptureAndLift(_:)),
            name: .captureAndLift, object: nil)

        sharedDrawingState.onWillUndo     = { [weak self] in self?.dismissAllLiftedCaptures() }
        sharedDrawingState.onWillRedo     = { [weak self] in self?.dismissAllLiftedCaptures() }
        sharedDrawingState.onWillClearAll = { [weak self] in self?.dismissAllLiftedCaptures() }
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
        // Local monitor: fires when Pointly's window is key. Handles all draw-mode shortcuts
        // and consumes them so they don't reach other apps.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOverlayActive else { return event }
            let ds = self.sharedDrawingState
            let im = self.sharedInteractionMode

            if let tool = Self.matchToolBinding(for: event) {
                if ProManager.shared.isLocked(tool) {
                    self.showPaywall(tool: tool, initialPlan: .annual)
                } else {
                    ds.selectTool(tool)
                    if im.currentMode == .interact { im.switchTo(mode: .draw) }
                    if let binding = ToolBindingsStore.shared.bindings[tool] {
                        NotificationCenter.default.post(name: .keystrokeHint, object: nil,
                            userInfo: ["tool": tool, "key": binding])
                    }
                }
                return nil
            }

            switch event.keyCode {
            case 51, 117: // ⌫ / ⌦
                if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { ds.clearAll() }
                    return nil
                }
                if ds.selectedTool == .select && !ds.selectedElementIDs.isEmpty {
                    DispatchQueue.main.async { ds.deleteSelected() }
                    return nil
                }
                if !self.liftedCaptures.isEmpty {
                    DispatchQueue.main.async { self.dismissLastLiftedCapture() }
                    return nil
                }
            case 13: // W
                if event.modifierFlags.contains(.command) {
                    if ProManager.shared.isPro {
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.4)) { ds.whiteboardMode.toggle() }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showPaywall(tool: nil, isWhiteboardCanvas: true, initialPlan: .annual)
                        }
                    }
                    return nil
                }
            case 53: // Escape — cancel text input; Cmd+Escape toggles interact mode
                if ds.isTextInputActive {
                    NotificationCenter.default.post(name: .cancelTextInput, object: nil)
                    return nil
                } else if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { im.toggleMode() }
                    return nil
                }
            default: break
            }
            return event
        }

        // Global draw monitor: fires when OTHER apps are focused and Accessibility is granted.
        // Cannot consume events but ensures shortcuts work without clicking the canvas first.
        globalDrawKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOverlayActive,
                  self.sharedInteractionMode.currentMode == .draw else { return }
            let ds = self.sharedDrawingState
            let im = self.sharedInteractionMode

            if let tool = Self.matchToolBinding(for: event) {
                DispatchQueue.main.async {
                    if ProManager.shared.isLocked(tool) {
                        self.showPaywall(tool: tool, initialPlan: .annual)
                    } else {
                        ds.selectTool(tool)
                        if let binding = ToolBindingsStore.shared.bindings[tool] {
                            NotificationCenter.default.post(name: .keystrokeHint, object: nil,
                                userInfo: ["tool": tool, "key": binding])
                        }
                    }
                }
                return
            }

            switch event.keyCode {
            case 51, 117:
                if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { ds.clearAll() }
                } else if ds.selectedTool == .select && !ds.selectedElementIDs.isEmpty {
                    DispatchQueue.main.async { ds.deleteSelected() }
                } else if !self.liftedCaptures.isEmpty {
                    DispatchQueue.main.async { self.dismissLastLiftedCapture() }
                }
            case 13:
                if event.modifierFlags.contains(.command) {
                    if ProManager.shared.isPro {
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.4)) { ds.whiteboardMode.toggle() }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showPaywall(tool: nil, isWhiteboardCanvas: true, initialPlan: .annual)
                        }
                    }
                }
            case 53:
                if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { im.toggleMode() }
                }
            default: break
            }
        }
    }

    private static func matchToolBinding(for event: NSEvent) -> DrawingTool? {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty else { return nil }
        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option)  { parts.append("⌥") }
        if mods.contains(.shift)   { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        guard let c = event.charactersIgnoringModifiers?.uppercased(),
              !c.isEmpty else { return nil }
        parts.append(c)
        let shortcut = parts.joined()
        return ToolBindingsStore.shared.bindings.first { $0.value == shortcut }?.key
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
        panel.hasShadow          = true
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

    @objc private func appDidBecomeActive() {
        guard isOverlayActive else { return }
        toolbarPanel?.orderFrontRegardless()
        // Restore canvas key status so drawing works immediately without a re-click
        let mainID = displayID(for: NSScreen.main ?? NSScreen.screens[0])
        canvasWindows[mainID]?.makeKey()
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
        let mainID = displayID(for: NSScreen.main ?? NSScreen.screens[0])
        canvasWindows[mainID]?.makeKey()

        if isInteract { installGlobalKeyMonitor() } else { removeGlobalKeyMonitor() }
    }

    // MARK: - Carbon tool hotkeys (works without Accessibility, like the main toggle)

    func registerToolHotkeys() {
        toolHotkeyManager.unregisterAll()
        let ds = sharedDrawingState
        let im = sharedInteractionMode

        for (tool, binding) in ToolBindingsStore.shared.bindings {
            var mods: NSEvent.ModifierFlags = []
            var keyChar = ""
            for ch in binding {
                switch ch {
                case "⌘": mods.insert(.command)
                case "⇧": mods.insert(.shift)
                case "⌥": mods.insert(.option)
                case "⌃": mods.insert(.control)
                default:   keyChar = String(ch)
                }
            }
            guard !keyChar.isEmpty, let keyCode = GlobalHotkeyManager.keyCode(for: keyChar) else { continue }
            let capturedTool = tool
            toolHotkeyManager.registerHotkey(keyCode: keyCode, modifiers: mods) { [weak self] in
                guard let self, self.isOverlayActive else { return }
                if ProManager.shared.isLocked(capturedTool) {
                    self.showPaywall(tool: capturedTool, initialPlan: .annual)
                } else {
                    ds.selectTool(capturedTool)
                    if im.currentMode == .interact { im.switchTo(mode: .draw) }
                    NotificationCenter.default.post(name: .keystrokeHint, object: nil,
                        userInfo: ["tool": capturedTool, "key": binding])
                }
            }
        }

        // Cmd+Z → undo (keyCode 6)
        toolHotkeyManager.registerHotkey(keyCode: 6, modifiers: .command) { [weak self] in
            guard let self, self.isOverlayActive else { return }
            DispatchQueue.main.async { ds.undo() }
        }

        // Cmd+Shift+Z → redo (keyCode 6)
        toolHotkeyManager.registerHotkey(keyCode: 6, modifiers: [.command, .shift]) { [weak self] in
            guard let self, self.isOverlayActive else { return }
            DispatchQueue.main.async { ds.redo() }
        }

        // Cmd+Backspace → clear all (keyCode 51 = delete)
        toolHotkeyManager.registerHotkey(keyCode: 51, modifiers: .command) { [weak self] in
            guard let self, self.isOverlayActive else { return }
            DispatchQueue.main.async { ds.clearAll() }
        }

        // Cmd+Escape → toggle interact/draw mode (keyCode 53)
        toolHotkeyManager.registerHotkey(keyCode: 53, modifiers: .command) { [weak self] in
            guard let self, self.isOverlayActive else { return }
            DispatchQueue.main.async { self.sharedInteractionMode.toggleMode() }
        }

        // Cmd+W → whiteboard (keyCode 13)
        toolHotkeyManager.registerHotkey(keyCode: 13, modifiers: .command) { [weak self] in
            guard let self, self.isOverlayActive else { return }
            if ProManager.shared.isPro {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.4)) { ds.whiteboardMode.toggle() }
                }
            } else {
                DispatchQueue.main.async { self.showPaywall(tool: nil, isWhiteboardCanvas: true) }
            }
        }

        // Cmd+= → increase size (keyCode 24 = equals/plus key)
        toolHotkeyManager.registerHotkey(keyCode: 24, modifiers: .command) { [weak self] in
            guard let self, self.isOverlayActive, ds.selectedTool.supportsThickness else { return }
            DispatchQueue.main.async { ds.strokeThickness = min(30, ds.strokeThickness + 1) }
        }

        // Cmd+- → decrease size (keyCode 27 = minus key)
        toolHotkeyManager.registerHotkey(keyCode: 27, modifiers: .command) { [weak self] in
            guard let self, self.isOverlayActive, ds.selectedTool.supportsThickness else { return }
            DispatchQueue.main.async { ds.strokeThickness = max(1, ds.strokeThickness - 1) }
        }
    }

    // MARK: - Global key monitor (interact mode only)
    // Local monitor fires only when Pointly is key. In interact mode the user
    // clicks other apps, so we add a global observer that runs regardless of
    // which app is frontmost. Global monitors cannot consume events, but they
    // can dispatch Pointly-side actions.

    private func installGlobalKeyMonitor() {
        guard globalKeyMonitor == nil else { return }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOverlayActive,
                  self.sharedInteractionMode.currentMode == .interact else { return }
            let ds = self.sharedDrawingState

            if let tool = Self.matchToolBinding(for: event) {
                DispatchQueue.main.async {
                    if ProManager.shared.isLocked(tool) {
                        self.showPaywall(tool: tool, initialPlan: .annual)
                    } else {
                        ds.selectTool(tool)
                        self.sharedInteractionMode.switchTo(mode: .draw)
                        if let binding = ToolBindingsStore.shared.bindings[tool] {
                            NotificationCenter.default.post(name: .keystrokeHint, object: nil,
                                userInfo: ["tool": tool, "key": binding])
                        }
                    }
                }
                return
            }

            switch event.keyCode {
            case 51, 117: // ⌫ / ⌦
                if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { ds.clearAll() }
                }
            case 13: // W
                if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { self.toggleWhiteboardMode() }
                }
            case 53: // Cmd+Escape
                if event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async { self.sharedInteractionMode.switchTo(mode: .draw) }
                }
            default: break
            }
        }
    }

    private func removeGlobalKeyMonitor() {
        // Only remove the interact-mode monitor; the draw-mode global monitor stays
        // registered permanently and self-guards via isOverlayActive.
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
    }

    // MARK: - Show / Hide

    func toggleOverlay() {
        if isOverlayActive { hideAll() } else { showAll() }
        isOverlayActive.toggle()
    }

    private func showAll() {
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
        registerToolHotkeys()
    }

    private func hideAll() {
        canvasWindows.values.forEach { $0.orderOut(nil) }
        toolbarPanel?.orderOut(nil)
        paywallPanel?.orderOut(nil)
        dismissAllLiftedCaptures()
        colorPanelObserver = nil
        NSColorPanel.shared.level = .floating
        removeGlobalKeyMonitor()
        toolHotkeyManager.unregisterAll()
    }

    // MARK: - Lifted capture management

    private func dismissLastLiftedCapture() {
        guard let last = liftedCaptures.last else { return }
        last.panel.orderOut(nil)
        sharedDrawingState.removeLiftedCover(id: last.coverID)
        liftedCaptures.removeLast()
    }

    private func dismissAllLiftedCaptures() {
        liftedCaptures.forEach { $0.panel.orderOut(nil) }
        liftedCaptures.removeAll()
        sharedDrawingState.clearLiftedCovers()
    }

    // MARK: - Cut & Move capture

    @objc private func handleCaptureAndLift(_ notification: Notification) {
        // Preflight is dialog-free. If not granted, open Settings and bail — the OS
        // dialog never appears this way, so there's nothing stuck on screen.
        if !CGPreflightScreenCaptureAccess() {
            sharedInteractionMode.switchTo(mode: .interact)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            return
        }

        guard let viewRect = notification.object as? CGRect else { return }
        let mainID = displayID(for: NSScreen.main ?? NSScreen.screens[0])
        guard let canvasWin = canvasWindows[mainID] else { return }

        // SwiftUI (top-left) → NSView (bottom-left) → AppKit screen rect
        let contentH = canvasWin.contentView?.frame.height ?? canvasWin.frame.height
        let nsViewRect = NSRect(
            x: viewRect.origin.x,
            y: contentH - viewRect.origin.y - viewRect.height,
            width: viewRect.width,
            height: viewRect.height
        )
        let screenRect = canvasWin.convertToScreen(nsViewRect)

        // AppKit → CG coordinates (origin = top-left of primary screen)
        let primaryH = NSScreen.screens.first?.frame.height ?? screenRect.maxY
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: primaryH - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.captureAndLift(viewRect: viewRect, screenRect: screenRect, cgRect: cgRect)
        }
    }

    @MainActor
    private func captureAndLift(viewRect: CGRect, screenRect: NSRect, cgRect: CGRect) async {
        guard let content = try? await SCShareableContent.current else { return }

        // Find the display that contains the selection
        guard let display = content.displays.first(where: { $0.frame.intersects(cgRect) })
                         ?? content.displays.first else { return }

        // Exclude Pointly's own windows so the canvas doesn't appear in the capture
        let ourPID = pid_t(ProcessInfo.processInfo.processIdentifier)
        let excluded = content.windows.filter { $0.owningApplication?.processID == ourPID }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)

        let cfg = SCStreamConfiguration()
        // sourceRect is relative to the display, in points, top-left origin
        cfg.sourceRect = CGRect(
            x: cgRect.minX - display.frame.minX,
            y: cgRect.minY - display.frame.minY,
            width: cgRect.width,
            height: cgRect.height
        )
        cfg.width  = Int(cgRect.width)
        cfg.height = Int(cgRect.height)
        cfg.scalesToFit = false

        guard let cgImage = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: cfg
        ) else { return }

        sharedDrawingState.deleteElements(in: viewRect)
        sharedInteractionMode.switchTo(mode: .interact)

        let fillColor = Color(sampleEdgeColor(of: cgImage))
        let coverID = sharedDrawingState.addLiftedCover(rect: viewRect, image: nil, fillColor: fillColor)

        let fgImage = NSImage(cgImage: cgImage, size: screenRect.size)
        let floatingRect = NSRect(x: screenRect.minX + 14, y: screenRect.minY - 14,
                                  width: screenRect.width, height: screenRect.height)
        showLiftedCapture(image: fgImage, floatingRect: floatingRect, coverID: coverID)
    }

    // Samples pixels from the outer 12% border of the CGImage and returns their
    // average color — a reliable approximation of the surrounding background.
    private func sampleEdgeColor(of cgImage: CGImage) -> NSColor {
        let side = 120
        guard let ctx = CGContext(data: nil, width: side, height: side,
                                  bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSColor(white: 0.08, alpha: 1)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = ctx.data else { return NSColor(white: 0.08, alpha: 1) }
        let ptr  = data.assumingMemoryBound(to: UInt8.self)
        let edge = max(1, side / 8)
        var r: Double = 0, g: Double = 0, b: Double = 0, n: Double = 0

        func add(_ offset: Int) {
            r += Double(ptr[offset]); g += Double(ptr[offset+1])
            b += Double(ptr[offset+2]); n += 1
        }
        for x in 0..<side {
            for y in 0..<edge {
                add((y * side + x) * 4)
                add(((side-1-y) * side + x) * 4)
            }
        }
        for y in edge..<(side-edge) {
            for x in 0..<edge {
                add((y * side + x) * 4)
                add((y * side + (side-1-x)) * 4)
            }
        }
        guard n > 0 else { return NSColor(white: 0.08, alpha: 1) }
        return NSColor(red: r/n/255, green: g/n/255, blue: b/n/255, alpha: 1)
    }

    private func showLiftedCapture(image: NSImage, floatingRect: NSRect, coverID: UUID) {
        let floating = NSPanel(
            contentRect: floatingRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        floating.level                = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        floating.backgroundColor      = .clear
        floating.isOpaque             = false
        floating.hasShadow            = true
        floating.ignoresMouseEvents   = false
        floating.isReleasedWhenClosed = false
        floating.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let captured = floating
        floating.contentView = FirstMouseHostingView(rootView:
            LiftedCaptureView(
                image: image,
                onDismiss: { [weak self] in
                    captured.orderOut(nil)
                    self?.sharedDrawingState.removeLiftedCover(id: coverID)
                    self?.liftedCaptures.removeAll { $0.panel === captured }
                },
                onGetFrame: { captured.frame },
                onSetFrame: { newFrame in captured.setFrame(newFrame, display: true) }
            )
        )
        liftedCaptures.append((panel: floating, coverID: coverID))
        floating.orderFrontRegardless()
    }

    // MARK: - Paywall

    @objc private func handleShowPaywall(_ notification: Notification) {
        guard let tool = notification.object as? DrawingTool else { return }
        showPaywall(tool: tool, initialPlan: .annual)
    }

    @objc private func handleShowPaywallForPlan(_ notification: Notification) {
        guard let plan = notification.object as? ProPlan else { return }
        showPaywall(tool: nil, initialPlan: plan)
    }

    func showPaywall(tool: DrawingTool?, isWhiteboardCanvas: Bool = false, initialPlan: ProPlan = .annual) {
        paywallPanel?.orderOut(nil)

        let size = CGSize(width: 400, height: 580)
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
            ProPaywallView(tool: tool, isWhiteboardCanvas: isWhiteboardCanvas,
                           proManager: .shared, onDismiss: { [weak self, weak panel] in
                panel?.orderOut(nil)
                self?.paywallPanel = nil
                if self?.isOverlayActive == true {
                    let mainID = self?.displayID(for: NSScreen.main ?? NSScreen.screens[0]) ?? 0
                    self?.canvasWindows[mainID]?.makeKey()
                }
            }, initialPlan: initialPlan)
        )
        panel.center()
        paywallPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    func lowerCanvasForPanel() {
        for win in canvasWindows.values { win.level = .normal }
    }

    @objc func restoreCanvasLevel() {
        applyModeToWindows()
    }

    func toggleWhiteboardMode() {
        guard ProManager.shared.isPro else {
            showPaywall(tool: nil, isWhiteboardCanvas: true, initialPlan: .annual)
            return
        }
        if !isOverlayActive { toggleOverlay() }
        withAnimation(.easeInOut(duration: 0.4)) { sharedDrawingState.whiteboardMode.toggle() }
    }
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
