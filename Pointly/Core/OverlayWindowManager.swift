import AppKit
import SwiftUI
import CoreGraphics

/// Manages one overlay window per screen, sharing a single drawing state and interaction mode.
/// Uses CGDirectDisplayID as key so windows survive NSScreen identity changes across reconnects.
class OverlayWindowManager: ObservableObject {
    // Keyed by stable display ID rather than NSScreen object identity
    private var overlayWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var isOverlayActive = false

    let sharedDrawingState = DrawingState()
    let sharedInteractionMode = InteractionModeManager()

    init() {
        buildWindows(for: NSScreen.screens)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        // Propagate mode changes (ignoresMouseEvents) to every window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyModeToAllWindows),
            name: .interactionModeChanged,
            object: nil
        )
    }

    // MARK: - Window Lifecycle

    private func buildWindows(for screens: [NSScreen]) {
        for screen in screens {
            let id = displayID(for: screen)
            guard id != 0, overlayWindows[id] == nil else { continue }
            overlayWindows[id] = makeWindow(for: screen)
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false   // starts in draw mode
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = OverlayView(
            drawingState: sharedDrawingState,
            interactionMode: sharedInteractionMode
        )
        window.contentView = NSHostingView(rootView: view)
        window.orderOut(nil)
        return window
    }

    @objc private func screensChanged() {
        let liveIDs = Set(NSScreen.screens.map { displayID(for: $0) })
        let existingIDs = Set(overlayWindows.keys)

        // Tear down windows for disconnected screens
        for id in existingIDs.subtracting(liveIDs) {
            overlayWindows[id]?.orderOut(nil)
            overlayWindows.removeValue(forKey: id)
        }

        // Create windows for newly connected screens
        buildWindows(for: NSScreen.screens)

        if isOverlayActive { showOnAllScreens() }
    }

    // MARK: - Mode → Window Sync

    @objc private func applyModeToAllWindows() {
        let passThrough = sharedInteractionMode.currentMode == .interact
        let level: NSWindow.Level = passThrough ? .floating : .screenSaver
        for window in overlayWindows.values {
            window.ignoresMouseEvents = passThrough
            window.level = level
        }
    }

    // MARK: - Show / Hide

    func toggleOverlay() {
        if isOverlayActive { hideOverlay() } else { showOverlay() }
    }

    private func showOverlay() {
        requestScreenRecordingPermission()
        showOnAllScreens()
        isOverlayActive = true
    }

    private func showOnAllScreens() {
        for (id, window) in overlayWindows {
            if let screen = screen(for: id) {
                window.setFrame(screen.frame, display: true)
            }
            window.orderFrontRegardless()
            if id == displayID(for: NSScreen.main ?? NSScreen.screens[0]) {
                window.makeKey()
            }
        }
        applyModeToAllWindows()
    }

    private func hideOverlay() {
        overlayWindows.values.forEach { $0.orderOut(nil) }
        isOverlayActive = false
    }

    // MARK: - Screen Recording Permission

    private func requestScreenRecordingPermission() {
        if CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) == nil {
            showPermissionAlert()
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Pointly needs screen recording permission. Please grant it in System Settings › Privacy & Security › Screen Recording."
        alert.alertStyle = .warning
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

    // MARK: - Public Interface

    var currentInteractionMode: InteractionModeManager? { sharedInteractionMode }
    var isActive: Bool { isOverlayActive }
}
