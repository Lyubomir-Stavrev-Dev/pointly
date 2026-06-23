import AppKit
import SwiftUI
import CoreGraphics

/// Manages one overlay window per screen, sharing a single drawing state and interaction mode
class OverlayWindowManager: ObservableObject {
    private var overlayWindows: [NSScreen: NSWindow] = [:]
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
    }

    // MARK: - Window Lifecycle

    private func buildWindows(for screens: [NSScreen]) {
        for screen in screens {
            guard overlayWindows[screen] == nil else { continue }
            let window = makeWindow(for: screen)
            overlayWindows[screen] = window
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
        window.ignoresMouseEvents = false
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
        let current = Set(NSScreen.screens)
        let existing = Set(overlayWindows.keys)

        // Remove windows for disconnected screens
        for screen in existing.subtracting(current) {
            overlayWindows[screen]?.orderOut(nil)
            overlayWindows.removeValue(forKey: screen)
        }

        // Add windows for new screens
        buildWindows(for: NSScreen.screens)

        // Re-show on all screens if overlay was active
        if isOverlayActive {
            showOnAllScreens()
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
        for (screen, window) in overlayWindows {
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            if screen == NSScreen.main {
                window.makeKey()
            }
        }
    }

    private func hideOverlay() {
        overlayWindows.values.forEach { $0.orderOut(nil) }
        isOverlayActive = false
    }

    // MARK: - Screen Recording Permission

    private func requestScreenRecordingPermission() {
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        if windowList == nil {
            showPermissionAlert()
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Pointly needs screen recording permission to function properly. Please grant permission in System Preferences > Security & Privacy > Privacy > Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Public Interface

    var currentInteractionMode: InteractionModeManager? { sharedInteractionMode }
    var isActive: Bool { isOverlayActive }
}
