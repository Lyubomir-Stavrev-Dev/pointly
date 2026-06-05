import AppKit
import SwiftUI
import CoreGraphics

/// Manages the overlay window system for screen annotations
class OverlayWindowManager: ObservableObject {
    private var overlayWindow: NSWindow?
    private var isOverlayActive = false
    
    init() {
        setupOverlayWindow()
    }
    
    private func setupOverlayWindow() {
        // Create a window that covers the entire screen
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        
        overlayWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        guard let window = overlayWindow else { return }
        
        // Configure window properties for overlay
        window.level = .screenSaver // High level to appear over other windows
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set up the content view
        let overlayView = OverlayView()
        window.contentView = NSHostingView(rootView: overlayView)
        
        // Initially hide the window
        window.orderOut(nil)
    }
    
    func toggleOverlay() {
        guard overlayWindow != nil else { return }
        
        if isOverlayActive {
            hideOverlay()
        } else {
            showOverlay()
        }
    }
    
    private func showOverlay() {
        guard let window = overlayWindow else { return }
        
        // Request screen recording permission if needed
        requestScreenRecordingPermission()
        
        // Update window frame to current screen
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        
        window.orderFrontRegardless()
        window.makeKey()
        
        isOverlayActive = true
    }
    
    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
        isOverlayActive = false
    }
    
    private func requestScreenRecordingPermission() {
        // Check and request screen recording permission
        // This is required for overlay functionality on macOS
        let options = CGWindowListOption.optionOnScreenOnly
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
        
        if windowList == nil {
            // Permission not granted - show alert or redirect to settings
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
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Preferences
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
}
