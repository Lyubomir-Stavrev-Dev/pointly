import AppKit
import SwiftUI
import CoreGraphics
import Combine
import ApplicationServices
import os.log

/// Pointly Phase 2.1 - Professional Version
/// Beautiful UI, comprehensive help, and smooth interactions

@main
struct PointlyTestApp: App {
    @NSApplicationDelegateAdaptor(TestAppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            TestSettingsView()
        }
    }
}

// MARK: - Test App Delegate with Professional Features

// Custom overlay window that can accept text input
class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func makeKey() {
        super.makeKey()
    }
    
    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        return super.makeFirstResponder(responder)
    }
}

class TestAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var overlayWindow: OverlayWindow?
    var helpWindow: NSWindow?
    @Published var interactionMode: InteractionMode = .draw
    @Published var currentTool: DrawingTool = .pen
    @Published var showHelp = false
    var isOverlayActive = false
    
    // Store event monitors to prevent deallocation
    private var globalEventMonitors: [Any] = []
    
    // OSLog for system log visibility
    private let logger = OSLog(subsystem: "com.pointly.macos", category: "hotkeys")
    
    // Shape drawing manager
    @Published var shapeManager = ShapeDrawingManager()
    
    // Text labels manager
    @Published var textManager = TextLabelsManager()
    
    // Selection system
    @Published var isSelecting: Bool = false
    @Published var selectionStart: CGPoint = .zero
    @Published var selectionEnd: CGPoint = .zero
    @Published var selectedObjects: Set<UUID> = []
    @Published var isDraggingSelection: Bool = false
    @Published var selectionDragOffset: CGPoint = .zero
    
    // Store initial positions for relative movement during drag
    var initialTextPositions: [UUID: CGPoint] = [:]
    var initialShapePositions: [UUID: CGPoint] = [:]
    
    // Freehand drawing paths for undo functionality
    @Published var drawingPaths: [DrawingPath] = []
    
    // Toolbar positioning and options
    @Published var toolbarPosition: ToolbarPosition = .bottom
    @Published var showOptionsMenu = false
    
    // Global stroke width for all tools
    @Published var globalStrokeWidth: Double = 5.0
    
    // Global color for drawings and shapes
    @Published var globalColor: Color = .blue
    
    // Toolbar scale (UI size)
    @Published var toolbarScale: Double = 0.8
    
    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        
        NSLog("🔵 TestAppDelegate.init() called - delegate is being created!")
        print("🔵 TestAppDelegate.init() called - delegate is being created!")
        
        // Sync global stroke width with shape manager
        $globalStrokeWidth
            .sink { newWidth in
                if self.isShapeTool(self.currentTool) {
                    self.shapeManager.strokeWidth = newWidth
                }
            }
            .store(in: &cancellables)
        
        // Keep text color in sync with global color when text tool is active
        $globalColor
            .sink { newColor in
                if self.currentTool == .text {
                    self.textManager.applyColorToSelectedLabels(newColor)
                }
            }
            .store(in: &cancellables)
        
        NSLog("🚀 Pointly Phase 2.1 - Professional Edition!")
        print("🚀 Pointly Phase 2.1 - Professional Edition!")
    }
    
    // Drawing path structure for freehand drawing
    struct DrawingPath: Identifiable {
        var points: [CGPoint]
        var tool: DrawingTool
        var color: Color
        var strokeWidth: Double
        var id = UUID()
    }
    
    
    // Phase 2.1: Interaction Modes
    enum InteractionMode: String, CaseIterable {
        case interact = "interact"
        case draw = "draw"
        
        var displayName: String {
            switch self {
            case .interact: return "Interact"
            case .draw: return "Draw"
            }
        }
        
        var description: String {
            switch self {
            case .interact: return "Click-through mode - interact with apps below"
            case .draw: return "Drawing mode - capture input for annotations"
            }
        }
        
        var icon: String {
            switch self {
            case .interact: return "hand.point.up.left.fill"
            case .draw: return "pencil.tip"
            }
        }
        
        var color: Color {
            switch self {
            case .interact: return .blue
            case .draw: return .orange
            }
        }
    }
    
    // Toolbar Positioning Options
    enum ToolbarPosition: String, CaseIterable {
        case top = "top"
        case bottom = "bottom"
        case left = "left"
        case right = "right"
        
        var displayName: String {
            switch self {
            case .top: return "Top"
            case .bottom: return "Bottom"
            case .left: return "Left"
            case .right: return "Right"
            }
        }
        
        var icon: String {
            switch self {
            case .top: return "arrow.up"
            case .bottom: return "arrow.down"
            case .left: return "arrow.left"
            case .right: return "arrow.right"
            }
        }
    }
    
    // Enhanced Drawing Tools
    enum DrawingTool: String, CaseIterable {
        case select = "select"
        case pen = "pen"
        case marker = "marker" 
        case laser = "laser"
        case blur = "blur"
        case eraser = "eraser"
        case shapes = "shapes"
        case text = "text"
        
        var displayName: String {
            switch self {
            case .select: return "Select"
            case .pen: return "Pen"
            case .marker: return "Marker"
            case .laser: return "Laser Pointer"
            case .blur: return "Blur Brush"
            case .eraser: return "Eraser"
            case .shapes: return "Shapes"
            case .text: return "Text"
            }
        }
        
        var icon: String {
            switch self {
            case .select: return "arrow.up.left.and.arrow.down.right"
            case .pen: return "pencil.tip"
            case .marker: return "paintbrush.pointed.fill"
            case .laser: return "dot.radiowaves.left.and.right"
            case .blur: return "camera.filters"
            case .eraser: return "eraser.fill"
            case .shapes: return "square.grid.3x3"
            case .text: return "textformat"
            }
        }
        
        var color: Color {
            switch self {
            case .select: return .blue
            case .pen: return .primary
            case .marker: return .green
            case .laser: return .red
            case .blur: return .purple
            case .eraser: return .secondary
            case .shapes: return .blue
            case .text: return .orange
            }
        }
        
        var description: String {
            switch self {
            case .select: return "Select and move objects without drawing"
            case .pen: return "Precise drawing with smooth lines"
            case .marker: return "Textured strokes with realistic blending"
            case .laser: return "Animated pointer with 3-second fade"
            case .blur: return "Screen-space blur for emphasis"
            case .eraser: return "Remove annotations cleanly"
            case .shapes: return "Draw shapes (Rectangle, Ellipse, Arrow, Line)"
            case .text: return "Add text labels with custom styling"
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Use NSLog which definitely goes to system logs
        NSLog("🚀 Pointly Phase 2.1 - Professional Edition!")
        os_log("🚀 Pointly Phase 2.1 - Professional Edition!", log: logger, type: .info)
        print("🚀 Pointly Phase 2.1 - Professional Edition!")
        
        // Hide dock icon - menu bar only
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar
        setupMenuBar()
        
        NSLog("🔑 About to setup global hotkeys...")
        os_log("🔑 About to setup global hotkeys...", log: logger, type: .info)
        
        // Setup global hotkeys
        setupGlobalHotkeys()
        
        NSLog("✅ Professional UI Ready!")
        os_log("✅ Professional UI Ready!", log: logger, type: .info)
        os_log("🔑 Hotkeys: ⌘⇧P, ⌘⌃P, ⌘⌥P to toggle overlay", log: logger, type: .info)
        print("✅ Professional UI Ready!")
        print("🔑 Press ⌘⇧P, ⌘⌃P, or ⌘⌥P to toggle overlay")
        print("🔑 Press ⌘⇧H or ⌘⌃H for help & shortcuts")
        print("🔑 Press Tab to toggle modes (when overlay active)")
        print("🔑 Click menu bar icon for quick access")
    }
    
    private func setupAlternativeHotkeys() {
        // Try using Carbon APIs as fallback
        print("🔄 Trying alternative hotkey registration...")
        
        // This is a simpler approach that might work better
        let alternativeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Try multiple alternative keys
            if event.keyCode == 111 { // F12 key
                print("✅ F12 detected - toggling overlay")
                DispatchQueue.main.async {
                    self.toggleOverlay()
                }
            } else if event.keyCode == 110 { // F11 key
                print("✅ F11 detected - toggling overlay")
                DispatchQueue.main.async {
                    self.toggleOverlay()
                }
            } else if event.keyCode == 109 { // F10 key
                print("✅ F10 detected - toggling overlay")
                DispatchQueue.main.async {
                    self.toggleOverlay()
                }
            }
        }
        
        if alternativeMonitor != nil {
            print("✅ Alternative hotkeys (F10, F11, F12) registered successfully")
            print("🔑 Try pressing F10, F11, or F12 to toggle overlay")
        } else {
            print("❌ Alternative hotkey registration also failed")
        }
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("🔍 Accessibility check: %@", isTrusted ? "GRANTED" : "NOT GRANTED")
        return isTrusted
    }
    
    private func checkInputMonitoringPermissions() -> Bool {
        // Input Monitoring is required for keyboard event monitoring on macOS 10.15+
        // This is separate from Accessibility permissions
        if #available(macOS 10.15, *) {
            // Try to create a monitor - if it returns nil, permissions aren't granted
            let testMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
            if testMonitor == nil {
                NSLog("⚠️  Input Monitoring permissions not granted")
                return false
            } else {
                NSEvent.removeMonitor(testMonitor!)
                NSLog("✅ Input Monitoring permissions granted")
                return true
            }
        }
        return true // Older macOS versions don't need this
    }
    
    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permissions Required for Global Hotkeys"
            alert.informativeText = "Pointly needs permissions to register global hotkeys (⌘⌃P).\n\n⚠️ IMPORTANT: On macOS 10.15+, you need BOTH permissions:\n\n1. Open System Settings > Privacy & Security\n2. Enable Pointly in:\n   • Accessibility\n   • Input Monitoring (REQUIRED for hotkeys!)\n3. Restart the app\n\nYou can still use the menu bar icon to toggle the overlay."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Privacy & Security
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(statusClicked)
            button.target = self
            button.toolTip = "Pointly - Professional Annotation Tool"
            
            // Add double-click to toggle overlay
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }
    
    private func setupGlobalHotkeys() {
        NSLog("🔑 Setting up global hotkeys...")
        os_log("🔑 Setting up global hotkeys...", log: logger, type: .info)
        print("🔑 Setting up global hotkeys...")
        
        // Check both Accessibility and Input Monitoring permissions
        let hasAccessibility = checkAccessibilityPermissions()
        let hasInputMonitoring = checkInputMonitoringPermissions()
        
        if !hasAccessibility || !hasInputMonitoring {
            NSLog("⚠️  Missing permissions - Accessibility: %@, Input Monitoring: %@", 
                  hasAccessibility ? "YES" : "NO",
                  hasInputMonitoring ? "YES" : "NO")
            os_log("⚠️  Missing permissions", log: logger, type: .error)
            print("⚠️  Missing permissions - showing alert...")
            showAccessibilityPermissionAlert()
            // Continue anyway - local monitor might still work
        } else {
            NSLog("✅ All permissions granted")
            os_log("✅ All permissions granted", log: logger, type: .info)
            print("✅ All permissions granted")
        }
        
        // Clear existing monitors
        for monitor in globalEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalEventMonitors.removeAll()
        
        // Use a single global monitor for all hotkeys
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Skip hotkey processing if user is editing text or an NSTextView is first responder
            if self.textManager.isEditing || self.textManager.editingLabel != nil || (NSApp.keyWindow?.firstResponder is NSTextView) {
                return
            }
            
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
            
            // Filter to only check the modifiers we care about
            let relevantModifiers = modifiers.intersection([.command, .control, .shift, .option])
            let hasCommand = relevantModifiers.contains(.command)
            let hasControl = relevantModifiers.contains(.control)
            let hasShift = relevantModifiers.contains(.shift)
            let hasOption = relevantModifiers.contains(.option)
            
            // Debug logging
            if keyCode == 35 || keyCode == 4 {
                os_log("🔍 Key detected: keyCode=%d, modifiers=%llu", log: logger, type: .debug, keyCode, modifiers.rawValue)
                os_log("🔍 Relevant: Cmd=%{public}@, Ctrl=%{public}@, Shift=%{public}@, Opt=%{public}@", log: logger, type: .debug, String(hasCommand), String(hasControl), String(hasShift), String(hasOption))
                print("🔍 Key detected: keyCode=\(keyCode), modifiers=\(modifiers.rawValue)")
                print("🔍 Relevant: Cmd=\(hasCommand), Ctrl=\(hasControl), Shift=\(hasShift), Opt=\(hasOption)")
            }
            
            // Check for overlay toggle (⌘⌃P, ⌘⇧P, ⌘⌥P)
            if keyCode == 35 { // P key
                if hasCommand && hasControl && !hasShift && !hasOption {
                    NSLog("✅ ⌘⌃P detected - toggling overlay")
                    os_log("✅ ⌘⌃P detected - toggling overlay", log: logger, type: .info)
                    print("✅ ⌘⌃P detected - toggling overlay")
                    DispatchQueue.main.async {
                        self.toggleOverlay()
                    }
                    return  // Exit early to avoid multiple triggers
                } else if hasCommand && hasShift && !hasControl && !hasOption {
                    NSLog("✅ ⌘⇧P detected - toggling overlay")
                    os_log("✅ ⌘⇧P detected - toggling overlay", log: logger, type: .info)
                    print("✅ ⌘⇧P detected - toggling overlay")
                    DispatchQueue.main.async {
                        self.toggleOverlay()
                    }
                    return
                } else if hasCommand && hasOption && !hasControl && !hasShift {
                    NSLog("✅ ⌘⌥P detected - toggling overlay")
                    os_log("✅ ⌘⌥P detected - toggling overlay", log: logger, type: .info)
                    print("✅ ⌘⌥P detected - toggling overlay")
                    DispatchQueue.main.async {
                        self.toggleOverlay()
                    }
                    return
                } else if keyCode == 35 && hasCommand && hasControl {
                    // Debug: log when Command+Control+P is pressed but conditions don't match
                    NSLog("⚠️ ⌘⌃P pressed but conditions not met: Shift=%@, Option=%@", 
                          hasShift ? "YES" : "NO", hasOption ? "YES" : "NO")
                    os_log("⚠️ ⌘⌃P pressed but conditions not met", log: logger, type: .debug)
                    print("⚠️ ⌘⌃P pressed but conditions not met: Shift=\(hasShift), Option=\(hasOption)")
                }
            }
            
            // Check for help window (⌘⌃H, ⌘⇧H)
            if keyCode == 4 { // H key
                if hasCommand && hasControl && !hasShift && !hasOption {
                    os_log("✅ ⌘⌃H detected - showing help", log: logger, type: .info)
                    print("✅ ⌘⌃H detected - showing help")
                    DispatchQueue.main.async {
                        self.showHelpWindow()
                    }
                } else if hasCommand && hasShift && !hasControl && !hasOption {
                    os_log("✅ ⌘⇧H detected - showing help", log: logger, type: .info)
                    print("✅ ⌘⇧H detected - showing help")
                    DispatchQueue.main.async {
                        self.showHelpWindow()
                    }
                }
            }
        }
        
        if let monitor = monitor {
            globalEventMonitors.append(monitor)
            NSLog("✅ Global hotkey monitor registered successfully (stored in array)")
            os_log("✅ Global hotkey monitor registered successfully", log: logger, type: .info)
            os_log("📋 Registered hotkeys: ⌘⌃P, ⌘⇧P, ⌘⌥P, ⌘⌃H, ⌘⇧H", log: logger, type: .info)
            print("✅ Global hotkey monitor registered successfully")
            print("📋 Registered hotkeys:")
            print("   • ⌘⌃P - Toggle overlay")
            print("   • ⌘⇧P - Toggle overlay (alternative)")
            print("   • ⌘⌥P - Toggle overlay (alternative)")
        } else {
            NSLog("❌ Failed to register global hotkey monitor")
            os_log("❌ Failed to register global hotkey monitor", log: logger, type: .error)
            print("❌ Failed to register global hotkey monitor")
        }
        
        // Also add a local monitor as backup (works even without Input Monitoring permission)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Skip hotkey processing if user is editing text or an NSTextView is first responder
            if self.textManager.isEditing || self.textManager.editingLabel != nil || (NSApp.keyWindow?.firstResponder is NSTextView) {
                return event
            }
            
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
            
            // Filter to only check the modifiers we care about
            let relevantModifiers = modifiers.intersection([.command, .control, .shift, .option])
            let hasCommand = relevantModifiers.contains(.command)
            let hasControl = relevantModifiers.contains(.control)
            let hasShift = relevantModifiers.contains(.shift)
            let hasOption = relevantModifiers.contains(.option)
            
            // Check for overlay toggle (⌘⌃P, ⌘⇧P, ⌘⌥P)
            if keyCode == 35 { // P key
                if hasCommand && hasControl && !hasShift && !hasOption {
                    NSLog("✅ ⌘⌃P detected (local monitor) - toggling overlay")
                    os_log("✅ ⌘⌃P detected (local monitor) - toggling overlay", log: logger, type: .info)
                    print("✅ ⌘⌃P detected (local monitor) - toggling overlay")
                    DispatchQueue.main.async {
                        self.toggleOverlay()
                    }
                    return nil  // Consume the event
                } else if hasCommand && hasShift && !hasControl && !hasOption {
                    NSLog("✅ ⌘⇧P detected (local monitor) - toggling overlay")
                    os_log("✅ ⌘⇧P detected (local monitor) - toggling overlay", log: logger, type: .info)
                    print("✅ ⌘⇧P detected (local monitor) - toggling overlay")
                    DispatchQueue.main.async {
                        self.toggleOverlay()
                    }
                    return nil
                } else if hasCommand && hasOption && !hasControl && !hasShift {
                    NSLog("✅ ⌘⌥P detected (local monitor) - toggling overlay")
                    os_log("✅ ⌘⌥P detected (local monitor) - toggling overlay", log: logger, type: .info)
                    print("✅ ⌘⌥P detected (local monitor) - toggling overlay")
                    DispatchQueue.main.async {
                        self.toggleOverlay()
                    }
                    return nil
                }
            }
            
            // Check for help window (⌘⌃H, ⌘⇧H)
            if keyCode == 4 { // H key
                if hasCommand && hasControl && !hasShift && !hasOption {
                    os_log("✅ ⌘⌃H detected (local monitor) - showing help", log: logger, type: .info)
                    print("✅ ⌘⌃H detected (local monitor) - showing help")
                    DispatchQueue.main.async {
                        self.showHelpWindow()
                    }
                    return nil
                } else if hasCommand && hasShift && !hasControl && !hasOption {
                    os_log("✅ ⌘⇧H detected (local monitor) - showing help", log: logger, type: .info)
                    print("✅ ⌘⇧H detected (local monitor) - showing help")
                    DispatchQueue.main.async {
                        self.showHelpWindow()
                    }
                    return nil
                }
            }
            
            return event  // Don't consume other events
        }
        
        if let localMonitor = localMonitor {
            globalEventMonitors.append(localMonitor)
            NSLog("✅ Local hotkey monitor registered successfully (backup)")
            os_log("✅ Local hotkey monitor registered successfully", log: logger, type: .info)
            print("✅ Local hotkey monitor registered successfully (backup)")
        }
        
        print("   • ⌘⌃H - Show help window")
        print("   • ⌘⇧H - Show help window (alternative)")
        NSLog("📊 Total monitors stored: %lu", globalEventMonitors.count)
        
        // Try alternative hotkey registration method
        setupAlternativeHotkeys()
    }
    
    @objc private func statusClicked() {
        let menu = NSMenu()
        
        // Status section
        let statusMenuItem = NSMenuItem(title: "Pointly Professional", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        if isOverlayActive {
            menu.addItem(NSMenuItem(title: "Overlay Active", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Mode: \(interactionMode.displayName)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Tool: \(currentTool.displayName)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            let hideOverlayItem = NSMenuItem(title: "Hide Overlay (⌘⌃P)", action: #selector(toggleOverlay), keyEquivalent: "")
            hideOverlayItem.target = self
            menu.addItem(hideOverlayItem)
            let toggleModeItem = NSMenuItem(title: "Toggle Mode (Tab)", action: #selector(toggleMode), keyEquivalent: "")
            toggleModeItem.target = self
            menu.addItem(toggleModeItem)
        } else {
            menu.addItem(NSMenuItem(title: "Overlay Inactive", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            let showOverlayItem = NSMenuItem(title: "Show Overlay (⌘⌃P)", action: #selector(toggleOverlay), keyEquivalent: "")
            showOverlayItem.target = self
            menu.addItem(showOverlayItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Options menu
        let optionsMenuItem = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
        let optionsMenu = NSMenu()
        
        // Toolbar Position submenu
        let positionMenuItem = NSMenuItem(title: "Toolbar Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()
        for position in ToolbarPosition.allCases {
            let positionItem = NSMenuItem(title: "\(position.displayName) Toolbar", action: #selector(setToolbarPosition(_:)), keyEquivalent: "")
            positionItem.representedObject = position
            // positionItem.state = toolbarPosition == position ? .on : .off
            positionMenu.addItem(positionItem)
        }
        positionMenuItem.submenu = positionMenu
        optionsMenu.addItem(positionMenuItem)
        
        optionsMenuItem.submenu = optionsMenu
        menu.addItem(optionsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        let helpMenuItem = NSMenuItem(title: "Help & Shortcuts (⌘⌃H)", action: #selector(showHelpWindow), keyEquivalent: "")
        helpMenuItem.target = self
        menu.addItem(helpMenuItem)
        menu.addItem(NSMenuItem.separator())
        let quitMenuItem = NSMenuItem(title: "Quit Pointly", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(self)
        statusItem?.menu = nil
    }
    
    @objc private func selectTool(_ sender: NSMenuItem) {
        if let tool = sender.representedObject as? DrawingTool {
            selectDrawingTool(tool)
        }
    }
    
    func selectDrawingTool(_ tool: DrawingTool) {
        currentTool = tool
        print("🎨 Selected: \(tool.displayName)")
        
        // Clear selection when switching tools
        selectedObjects.removeAll()
        isSelecting = false
        isDraggingSelection = false
        selectionDragOffset = .zero
        
        // Force finish any text editing when switching tools
        textManager.forceFinishEditing()
        
        // Enable text creation when text tool is selected
        if tool == .text {
            textManager.enableTextCreation()
            textManager.applyColorToSelectedLabels(globalColor)
        }
        
        // Sync with shape manager for shape tools
        if isShapeTool(tool) {
            // When shapes tool is selected, default to rectangle
            shapeManager.setShapeType(ShapeType.rectangle)
            // Sync stroke width
            shapeManager.strokeWidth = globalStrokeWidth
        }
    }
    
    @objc private func setToolbarPosition(_ sender: NSMenuItem) {
        if let position = sender.representedObject as? ToolbarPosition {
            toolbarPosition = position
            print("📍 Toolbar position set to: \(position.displayName)")
            
            // Update menu states
            updateMenuStates()
        }
    }
    
    private func updateMenuStates() {
        // This would update the menu item states, but for now we'll just print
        print("🔄 Menu states updated for position: \(toolbarPosition.displayName)")
    }
    
    private func isShapeTool(_ tool: DrawingTool) -> Bool {
        return tool == .shapes
    }
    
    private func isTextTool(_ tool: DrawingTool) -> Bool {
        let isText = tool == .text
        print("🔍 isTextTool(\(tool.displayName)) = \(isText)")
        return isText
    }
    
    @objc private func toggleOverlay() {
        if isOverlayActive {
            hideOverlay()
        } else {
            showOverlay()
        }
    }
    
    private func showOverlay() {
        guard overlayWindow == nil else { return }
        
        // Clear all previous state when showing overlay
        textManager.clearAll()
        shapeManager.clearAll()
        drawingPaths.removeAll()
        selectedObjects.removeAll()
        print("🧹 showOverlay: Cleared all state before showing")
        
        // Create overlay window - use visibleFrame to exclude menu bar and dock
        let screen = NSScreen.main ?? NSScreen.screens.first!
        // visibleFrame automatically excludes menu bar and dock
        let windowFrame = screen.visibleFrame
        
        overlayWindow = OverlayWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        guard let window = overlayWindow else { return }
        
        // Configure for overlay - use floating level but visibleFrame excludes menu bar
        window.level = .floating
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        // Make sure window is visible and on top
        window.alphaValue = 1.0
        
        // Set content view
        let overlayView = ProfessionalOverlayView(appDelegate: self)
        window.contentView = NSHostingView(rootView: overlayView)
        
        // Apply current mode
        applyInteractionMode()
        
        // Make sure window can receive events
        window.makeKey()
        _ = window.makeFirstResponder(window.contentView)
        window.orderFrontRegardless()
        
        // Force window to front
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        isOverlayActive = true
        updateMenuBarIcon()
        
        print("✅ Professional overlay activated - \(interactionMode.displayName) mode")
        print("🪟 Window frame: \(window.frame)")
        print("🪟 Window level: \(window.level.rawValue)")
        print("🪟 Window is visible: \(window.isVisible)")
    }
    
    @objc func hideOverlay() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        isOverlayActive = false
        updateMenuBarIcon()
        
        // Clear all state when overlay is hidden
        textManager.clearAll()
        shapeManager.clearAll()
        drawingPaths.removeAll()
        selectedObjects.removeAll()
        
        print("✅ Overlay hidden and state cleared")
    }
    
    @objc func toggleMode() {
        guard isOverlayActive else { return }
        
        interactionMode = interactionMode == .draw ? .interact : .draw
        applyInteractionMode()
        updateMenuBarIcon()
        
        print("🔄 Mode switched to: \(interactionMode.displayName)")
    }
    
    private func applyInteractionMode() {
        guard let window = overlayWindow else { return }
        
        switch interactionMode {
        case .interact:
            window.ignoresMouseEvents = true
            window.level = .floating  // Floating level, but visibleFrame excludes menu bar
        case .draw:
            window.ignoresMouseEvents = false
            window.level = .floating  // Floating level, but visibleFrame excludes menu bar
            window.acceptsMouseMovedEvents = true
        }
    }
    
    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        
        if isOverlayActive {
            button.image = NSImage(systemSymbolName: interactionMode.icon, accessibilityDescription: "Pointly - \(interactionMode.displayName)")
        } else {
            button.image = NSImage(systemSymbolName: "pencil.circle.fill", accessibilityDescription: "Pointly")
        }
    }
    
    
    private func showNotification(title: String, message: String) {
        // Use a simple alert instead of deprecated notifications
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                alert.window.orderOut(nil)
            }
            
            alert.runModal()
        }
    }
    
    @objc private func showHelpWindow() {
        print("📖 showHelpWindow called")
        
        // If window exists, bring it to front
        if let existingWindow = helpWindow {
            print("📖 Help window exists, bringing to front")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        print("📖 Creating new help window")
        helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = helpWindow else {
            print("❌ Failed to create help window")
            return
        }
        
        window.title = "Pointly - Help & Shortcuts"
        window.center()
        
        let helpView = HelpView()
        window.contentView = NSHostingView(rootView: helpView)
        
        // Clean up when closed - store delegate to prevent deallocation
        let delegate = HelpWindowDelegate { [weak self] in
            print("📖 Help window closed")
            self?.helpWindow = nil
        }
        window.delegate = delegate
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ Help window shown")
    }
    
    @objc private func showTestDialog() {
        let alert = NSAlert()
        alert.messageText = "🧪 Pointly Professional Testing"
        alert.informativeText = """
        Ready to test all features:
        
        ✅ Beautiful modern UI
        ✅ Professional interaction modes
        ✅ Advanced drawing tools
        ✅ Comprehensive keyboard shortcuts
        ✅ Help system & documentation
        
        Press ⌘⌃P to start testing!
        Press ⌘⌃H for complete help guide.
        """
        alert.addButton(withTitle: "Start Testing!")
        alert.addButton(withTitle: "Show Help First")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            showHelpWindow()
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Undo/Redo Functionality
    
    func performUndo() {
        print("🔄 Performing undo...")
        
        // Check what can be undone - prioritize most recent action
        let hasDrawingPaths = !drawingPaths.isEmpty
        let hasShapes = !shapeManager.drawnShapes.isEmpty
        let hasText = !textManager.textLabels.isEmpty
        
        // Undo text labels first (most recent)
        if hasText {
            textManager.textLabels.removeLast()
            print("✅ Undid text label")
            return
        }
        
        // Undo shape drawing
        if hasShapes {
            shapeManager.undoLast()
            print("✅ Undid shape drawing")
            return
        }
        
        // Undo freehand drawing
        if hasDrawingPaths {
            drawingPaths.removeLast()
            print("✅ Undid freehand drawing path")
            return
        }
        
        print("ℹ️ Nothing to undo")
    }
    
    private func performRedo() {
        print("🔄 Performing redo...")
        // For now, we'll implement a simple redo by showing a message
        // In a full implementation, we'd maintain a redo stack
        print("ℹ️ Redo not yet implemented - would restore last undone action")
    }
}

// MARK: - Professional Overlay View

struct ProfessionalOverlayView: View {
    @ObservedObject var appDelegate: TestAppDelegate
    @State private var currentPath: TestAppDelegate.DrawingPath?
    @State private var showToolPalette = true
    @State private var showShapePalette = false
    
    init(appDelegate: TestAppDelegate) {
        self.appDelegate = appDelegate
    }
    
    
    var body: some View {
        ZStack {
            // Transparent background for drawing - only active for non-text tools
            Color.clear
                .contentShape(Rectangle())
                .onHover { _ in
                    // Change cursor based on tool
                    if isTextToolForCurrentTool() {
                        NSCursor.iBeam.set()
                    } else if isSelectToolForCurrentTool() {
                        NSCursor.arrow.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            print("🎯 DRAG CHANGED! Mode: \(appDelegate.interactionMode.displayName), Location: \(value.location)")
                            
                            // Handle Select tool
                            if isSelectToolForCurrentTool() {
                                // Check if drag starts on a selected object
                                let dragStartOnSelected = isPointOnSelectedObject(value.startLocation)
                                
                                // If we have selected objects and drag starts on one, move them
                                if !appDelegate.selectedObjects.isEmpty && dragStartOnSelected && !appDelegate.isSelecting {
                                    if !appDelegate.isDraggingSelection {
                                        appDelegate.isDraggingSelection = true
                                        appDelegate.selectionDragOffset = .zero
                                        // Store initial positions for relative movement
                                        storeInitialPositions()
                                        print("🎯 SELECT: Started dragging selected objects")
                                    }
                                    let newOffset = CGPoint(x: value.translation.width, y: value.translation.height)
                                    let relativeOffset = CGPoint(
                                        x: newOffset.x - appDelegate.selectionDragOffset.x,
                                        y: newOffset.y - appDelegate.selectionDragOffset.y
                                    )
                                    appDelegate.selectionDragOffset = newOffset
                                    moveSelectedObjects(by: relativeOffset)
                                    return
                                }
                                
                                // Otherwise, start selection rectangle
                                if !appDelegate.isSelecting {
                                    appDelegate.isSelecting = true
                                    appDelegate.selectionStart = value.startLocation
                                    print("🎯 SELECT: Started selection at \(value.startLocation)")
                                }
                                appDelegate.selectionEnd = value.location
                                print("🎯 SELECT: Updated selection end to \(value.location), isSelecting: \(appDelegate.isSelecting)")
                                return
                            }
                            
                            // Handle dragging selected objects (only if not selecting)
                            if !appDelegate.selectedObjects.isEmpty && !appDelegate.isSelecting {
                                if !appDelegate.isDraggingSelection {
                                    appDelegate.isDraggingSelection = true
                                    appDelegate.selectionDragOffset = .zero
                                    // Store initial positions for relative movement
                                    storeInitialPositions()
                                    print("🎯 SELECT: Started dragging selected objects")
                                }
                                let newOffset = CGPoint(x: value.translation.width, y: value.translation.height)
                                let relativeOffset = CGPoint(
                                    x: newOffset.x - appDelegate.selectionDragOffset.x,
                                    y: newOffset.y - appDelegate.selectionDragOffset.y
                                )
                                appDelegate.selectionDragOffset = newOffset
                                moveSelectedObjects(by: relativeOffset)
                                return
                            }
                            
                            // Handle dragging selected text labels (only if not selecting)
                            if let selectedLabel = appDelegate.textManager.selectedLabel, !appDelegate.isSelecting {
                                print("📝 DRAG: Moving selected text label")
                                appDelegate.textManager.updateLabelPosition(selectedLabel, to: value.location)
                                return
                            }
                            
                            // Handle drawing tools (only if not selecting and not dragging selection and not text tool)
                            if !appDelegate.isSelecting && !appDelegate.isDraggingSelection && !isTextToolForCurrentTool() {
                                handleDrawingChanged(value)
                            }
                        }
                        .onEnded { value in
                            print("🎯 DRAG ENDED! Mode: \(appDelegate.interactionMode.displayName)")
                            
                            // Handle Select tool - finish selection
                            if isSelectToolForCurrentTool() && appDelegate.isSelecting {
                                print("🎯 SELECT: Finishing selection from \(appDelegate.selectionStart) to \(appDelegate.selectionEnd)")
                                appDelegate.isSelecting = false
                                selectObjectsInRectangle(appDelegate.selectionStart, appDelegate.selectionEnd)
                                print("🎯 SELECT: Selected \(appDelegate.selectedObjects.count) objects")
                                return
                            }
                            
                            // Handle dragging selected objects
                            if appDelegate.isDraggingSelection {
                                appDelegate.isDraggingSelection = false
                                let finalOffset = appDelegate.selectionDragOffset
                                moveSelectedObjects(by: finalOffset)
                                appDelegate.selectionDragOffset = .zero
                                print("🎯 SELECTION: Finished dragging, moved by \(finalOffset)")
                                return
                            }
                            
                            // Handle dragging selected text labels
                            if appDelegate.textManager.selectedLabel != nil {
                                print("📝 DRAG END: Finished moving text label")
                                return
                            }
                            
                            handleDrawingEnded(value)
                        }
                )
                .onTapGesture { location in
                    print("🎯 MAIN OVERLAY TAP DETECTED! Mode: \(appDelegate.interactionMode.displayName) at \(location)")
                    print("🔍 Current tool: \(appDelegate.currentTool.displayName)")
                    print("🔍 isTextToolForCurrentTool(): \(isTextToolForCurrentTool())")
                    print("🔍 shouldCreateNewText: \(appDelegate.textManager.shouldCreateNewText)")
                    print("🔍 textLabels count: \(appDelegate.textManager.textLabels.count)")

                    // Check if tap is on an existing text label
                    let tappedLabel = appDelegate.textManager.textLabels.first { label in
                        let labelRect = CGRect(
                            x: label.position.x - label.size.width/2,
                            y: label.position.y - label.size.height/2,
                            width: label.size.width,
                            height: label.size.height
                        )
                        return labelRect.contains(location)
                    }

                    if let tappedLabel = tappedLabel {
                        print("📝 TAP: Clicked on existing label '\(tappedLabel.text)'")
                        appDelegate.textManager.selectLabel(tappedLabel)
                        return
                    }

                    // If we clicked outside any text label, deselect everything
                    print("📝 TAP: Clicked outside text labels - deselecting all")
                    
                    // Clear selection if select tool is active
                    if isSelectToolForCurrentTool() {
                        print("📝 SELECT TOOL: Clearing selection")
                        appDelegate.selectedObjects.removeAll()
                    }
                    
                    // Force finish editing for all labels
                    appDelegate.textManager.forceFinishEditing()
                    
                    // Deselect all text labels
                    appDelegate.textManager.deselectAll()

                    // Only create new text if text tool is selected AND we should create new text
                    let shouldCreateNew = isTextToolForCurrentTool() && appDelegate.textManager.shouldCreateNewText
                    print("🔍 shouldCreateNew: \(shouldCreateNew), isTextTool: \(isTextToolForCurrentTool()), shouldCreateNewText: \(appDelegate.textManager.shouldCreateNewText)")

                    if shouldCreateNew {
                        print("📝 TEXT TOOL TAP: Adding new label at \(location)")
                        appDelegate.textManager.addLabel(at: location)
                    } else if isTextToolForCurrentTool() {
                        print("📝 TEXT TOOL TAP: First click - enabling text creation for next click")
                        appDelegate.textManager.shouldCreateNewText = true
                    } else {
                        print("📝 TAP: No new text creation - not text tool")
                    }
                }
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            print("🎯 MAIN OVERLAY DOUBLE-TAP DETECTED!")
                            
                            // For now, just start editing the selected label if any
                            if let selectedLabel = appDelegate.textManager.selectedLabel {
                                print("📝 DOUBLE-TAP: Starting edit for selected label '\(selectedLabel.text)'")
                                appDelegate.textManager.editingLabel = selectedLabel
                                appDelegate.textManager.isEditing = true
                            }
                        }
                )
            
            // Drawing canvas - make sure it's on top
            ZStack {
                // Freehand drawing canvas
                Canvas { context, size in
                    drawPaths(context: context)
                }
                .allowsHitTesting(false) // Allow clicks to pass through to background
                
                // Shape drawing canvas - always visible, only interactive when shapes tool is selected
                ShapeDrawingCanvas(shapeManager: appDelegate.shapeManager, globalColor: appDelegate.globalColor)
                    .allowsHitTesting(appDelegate.interactionMode == .draw && isShapeTool(appDelegate.currentTool))
            }
            
            // Text labels canvas - allow hit testing so resize handles can be dragged
            TextLabelsCanvas(textManager: appDelegate.textManager)
                .allowsHitTesting(true)
                .zIndex(20000)
            
            // Resize handles overlay removed (now rendered inside TextLabelView)
            
            // Selection rectangle
            if appDelegate.isSelecting {
                let width = abs(appDelegate.selectionEnd.x - appDelegate.selectionStart.x)
                let height = abs(appDelegate.selectionEnd.y - appDelegate.selectionStart.y)
                let centerX = (appDelegate.selectionStart.x + appDelegate.selectionEnd.x) / 2
                let centerY = (appDelegate.selectionStart.y + appDelegate.selectionEnd.y) / 2
                
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.1))
                    .frame(width: width, height: height)
                    .position(x: centerX, y: centerY)
                    .onAppear {
                        print("🎯 DRAWING SELECTION: width=\(width), height=\(height), center=(\(centerX), \(centerY))")
                    }
            }
            
            // Text formatting toolbar - appears when text is selected or editing.
            // Position above the main tool palette when palette is at bottom; otherwise near top.
            if appDelegate.textManager.selectedLabel != nil || appDelegate.textManager.editingLabel != nil {
                VStack {
                    if appDelegate.toolbarPosition == .bottom {
                        Spacer()
                        TextFormattingToolbar(textManager: appDelegate.textManager)
                            .padding(.bottom, 180) // lift above bottom palette
                    } else {
                        TextFormattingToolbar(textManager: appDelegate.textManager)
                            .padding(.top, 60)
                        Spacer()
                    }
                }
                .zIndex(50000)
            }
            
            
            // Professional UI overlay with dynamic positioning
            ZStack {
                // Top toolbar
                if appDelegate.toolbarPosition == .top && appDelegate.interactionMode == .draw && showToolPalette {
                    VStack {
                        HStack(spacing: 16) {
                            CompactToolPalette(appDelegate: appDelegate, drawingPaths: $appDelegate.drawingPaths)
                            if isShapeTool(appDelegate.currentTool) {
                                CompactShapePalette(shapeManager: appDelegate.shapeManager, appDelegate: appDelegate)
                            }
                        }
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }
                
                // Bottom toolbar
                if appDelegate.toolbarPosition == .bottom && appDelegate.interactionMode == .draw && showToolPalette {
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            CompactToolPalette(appDelegate: appDelegate, drawingPaths: $appDelegate.drawingPaths)
                            if isShapeTool(appDelegate.currentTool) {
                                CompactShapePalette(shapeManager: appDelegate.shapeManager, appDelegate: appDelegate)
                            }
                        }
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Left toolbar (vertical)
                if appDelegate.toolbarPosition == .left && appDelegate.interactionMode == .draw && showToolPalette {
                    HStack {
                        VStack(spacing: 8) {
                            VerticalToolPalette(appDelegate: appDelegate, drawingPaths: $appDelegate.drawingPaths)
                            if isShapeTool(appDelegate.currentTool) {
                                VerticalShapePalette(shapeManager: appDelegate.shapeManager, appDelegate: appDelegate)
                            }
                        }
                        .padding(.leading, 20)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                }
                
                // Right toolbar (vertical)
                if appDelegate.toolbarPosition == .right && appDelegate.interactionMode == .draw && showToolPalette {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            VerticalToolPalette(appDelegate: appDelegate, drawingPaths: $appDelegate.drawingPaths)
                            if isShapeTool(appDelegate.currentTool) {
                                VerticalShapePalette(shapeManager: appDelegate.shapeManager, appDelegate: appDelegate)
                            }
                        }
                        .padding(.trailing, 20)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                
                // Status bar (always at top when in interact mode)
                if appDelegate.interactionMode == .interact {
                    VStack {
                        HStack {
                            StatusCard(
                                mode: appDelegate.interactionMode,
                                tool: appDelegate.currentTool
                            )
                            Spacer()
                            QuickActions(appDelegate: appDelegate)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
            
            // Keyboard shortcuts overlay (press H)
            if appDelegate.showHelp {
                KeyboardShortcutsOverlay(appDelegate: appDelegate)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showToolPalette)
        .animation(.easeInOut(duration: 0.3), value: appDelegate.showHelp)
    }
    
    private func isShapeTool(_ tool: TestAppDelegate.DrawingTool) -> Bool {
        return tool == .shapes
    }
    
    private func isTextTool(_ tool: TestAppDelegate.DrawingTool) -> Bool {
        return tool == .text
    }
    
    private func isTextToolForCurrentTool() -> Bool {
        return appDelegate.currentTool == .text
    }
    
    private func isSelectToolForCurrentTool() -> Bool {
        return appDelegate.currentTool == .select
    }
    
    // Selection helper functions
    private func selectObjectsInRectangle(_ start: CGPoint, _ end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        print("🎯 SELECT: Selection rectangle: \(rect)")
        
        var newSelection: Set<UUID> = []
        
        // Select text labels in rectangle
        for label in appDelegate.textManager.textLabels {
            let labelRect = CGRect(
                x: label.position.x - label.size.width/2,
                y: label.position.y - label.size.height/2,
                width: label.size.width,
                height: label.size.height
            )
            print("🎯 SELECT: Checking label '\(label.text)' at \(labelRect)")
            if rect.intersects(labelRect) {
                newSelection.insert(label.id)
                print("🎯 SELECT: Text label '\(label.text)' selected")
            }
        }
        
        // Select shapes in rectangle
        for shape in appDelegate.shapeManager.drawnShapes {
            let shapeRect = CGRect(
                x: min(shape.startPoint.x, shape.endPoint.x),
                y: min(shape.startPoint.y, shape.endPoint.y),
                width: abs(shape.endPoint.x - shape.startPoint.x),
                height: abs(shape.endPoint.y - shape.startPoint.y)
            )
            if rect.intersects(shapeRect) {
                newSelection.insert(shape.id)
            }
        }
        
        appDelegate.selectedObjects = newSelection
        print("🎯 SELECT: Total selected objects: \(newSelection.count)")
        
        // Update text label selection states
        // First, deselect all labels
        appDelegate.textManager.deselectAll()
        
        // Then select only the ones in the new selection
        for label in appDelegate.textManager.textLabels {
            if newSelection.contains(label.id) {
                if let index = appDelegate.textManager.textLabels.firstIndex(where: { $0.id == label.id }) {
                    appDelegate.textManager.textLabels[index].isSelected = true
                }
            }
        }
        
        // Set the selected label to the first one (if any)
        if let firstSelectedId = newSelection.first {
            if let firstLabel = appDelegate.textManager.textLabels.first(where: { $0.id == firstSelectedId }) {
                appDelegate.textManager.selectedLabel = firstLabel
            }
        } else {
            appDelegate.textManager.selectedLabel = nil
        }
        
        print("🎯 SELECTION: Selected \(newSelection.count) objects")
    }
    
    private func isPointOnSelectedObject(_ point: CGPoint) -> Bool {
        // Check if point is on a selected text label
        for label in appDelegate.textManager.textLabels {
            if appDelegate.selectedObjects.contains(label.id) {
                let labelRect = CGRect(
                    x: label.position.x - label.size.width/2,
                    y: label.position.y - label.size.height/2,
                    width: label.size.width,
                    height: label.size.height
                )
                if labelRect.contains(point) {
                    return true
                }
            }
        }
        
        // Check if point is on a selected shape
        for shape in appDelegate.shapeManager.drawnShapes {
            if appDelegate.selectedObjects.contains(shape.id) {
                let shapeRect = CGRect(
                    x: min(shape.startPoint.x, shape.endPoint.x),
                    y: min(shape.startPoint.y, shape.endPoint.y),
                    width: abs(shape.endPoint.x - shape.startPoint.x),
                    height: abs(shape.endPoint.y - shape.startPoint.y)
                )
                if shapeRect.contains(point) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func storeInitialPositions() {
        appDelegate.initialTextPositions.removeAll()
        appDelegate.initialShapePositions.removeAll()
        
        // Store initial text positions
        for label in appDelegate.textManager.textLabels {
            if appDelegate.selectedObjects.contains(label.id) {
                appDelegate.initialTextPositions[label.id] = label.position
            }
        }
        
        // Store initial shape positions
        for shape in appDelegate.shapeManager.drawnShapes {
            if appDelegate.selectedObjects.contains(shape.id) {
                let centerX = (shape.startPoint.x + shape.endPoint.x) / 2
                let centerY = (shape.startPoint.y + shape.endPoint.y) / 2
                appDelegate.initialShapePositions[shape.id] = CGPoint(x: centerX, y: centerY)
            }
        }
    }
    
    private func moveSelectedObjects(by offset: CGPoint) {
        // Move selected text labels using initial positions
        for label in appDelegate.textManager.textLabels {
            if appDelegate.selectedObjects.contains(label.id),
               let initialPos = appDelegate.initialTextPositions[label.id] {
                appDelegate.textManager.updateLabelPosition(label, to: CGPoint(
                    x: initialPos.x + offset.x,
                    y: initialPos.y + offset.y
                ))
            }
        }
        
        // Move selected shapes using initial positions
        for shape in appDelegate.shapeManager.drawnShapes {
            if appDelegate.selectedObjects.contains(shape.id),
               let initialPos = appDelegate.initialShapePositions[shape.id] {
                appDelegate.shapeManager.updateShapePosition(shape, to: CGPoint(
                    x: initialPos.x + offset.x,
                    y: initialPos.y + offset.y
                ))
            }
        }
        
        print("🎯 SELECTION: Moved \(appDelegate.selectedObjects.count) objects by \(offset)")
    }
    
    private func handleEraser(at location: CGPoint) {
        print("🧹 Erasing at: \(location)")
        
        // Erase shapes first (check if eraser is near any shape)
        let eraserRadius: CGFloat = 20.0 // Eraser radius
        
        // Check shapes for erasure
        for (index, shape) in appDelegate.shapeManager.drawnShapes.enumerated().reversed() {
            if isPointNearShape(location, shape: shape, radius: eraserRadius) {
                print("🧹 Erasing shape: \(shape.type.displayName)")
                appDelegate.shapeManager.drawnShapes.remove(at: index)
                return
            }
        }
        
        // Check freehand paths for erasure
        for (index, path) in appDelegate.drawingPaths.enumerated().reversed() {
            if isPointNearPath(location, path: path, radius: eraserRadius) {
                print("🧹 Erasing freehand path")
                appDelegate.drawingPaths.remove(at: index)
                return
            }
        }
        
        print("ℹ️ Nothing to erase at this location")
    }
    
    private func isPointNearShape(_ point: CGPoint, shape: DrawnShape, radius: CGFloat) -> Bool {
        let rect = shape.boundingRect
        let expandedRect = rect.insetBy(dx: -radius, dy: -radius)
        return expandedRect.contains(point)
    }
    
    private func isPointNearPath(_ point: CGPoint, path: TestAppDelegate.DrawingPath, radius: CGFloat) -> Bool {
        for pathPoint in path.points {
            let distance = sqrt(pow(point.x - pathPoint.x, 2) + pow(point.y - pathPoint.y, 2))
            if distance <= radius {
                return true
            }
        }
        return false
    }
    
    private func handleDrawingChanged(_ value: DragGesture.Value) {
        guard appDelegate.interactionMode == .draw else { 
            print("🚫 Drawing blocked - not in Draw mode")
            return 
        }
        
        print("🎨 Drawing changed at: \(value.location)")
        
        // Handle eraser tool
        if appDelegate.currentTool == .eraser {
            handleEraser(at: value.location)
            return
        }
        
        // Handle shape tools differently
        if isShapeTool(appDelegate.currentTool) {
            // Shape tools are handled by ShapeDrawingCanvas
            return
        }
        
        // Handle text tool
        if isTextToolForCurrentTool() {
            print("📝 TEXT TOOL: Adding label at \(value.location)")
            appDelegate.textManager.addLabel(at: value.location)
            return
        }
        
        // Handle select tool - don't create new objects, just handle selection
        if isSelectToolForCurrentTool() {
            print("📝 SELECT TOOL: Drag detected, no new objects created")
            return
        }
        
        // Handle freehand drawing tools
        if currentPath == nil {
            currentPath = TestAppDelegate.DrawingPath(
                points: [value.location],
                tool: appDelegate.currentTool,
                color: appDelegate.globalColor,
                strokeWidth: appDelegate.globalStrokeWidth
            )
            print("🆕 Started new path with \(appDelegate.currentTool.displayName)")
        } else {
            currentPath?.points.append(value.location)
            print("➕ Added point to path, total points: \(currentPath?.points.count ?? 0)")
        }
    }
    
    private func handleDrawingEnded(_ value: DragGesture.Value) {
        guard appDelegate.interactionMode == .draw,
              let path = currentPath else { return }
        
        appDelegate.drawingPaths.append(path)
        currentPath = nil
    }
    
    
    private func drawPaths(context: GraphicsContext) {
        print("🎨 Drawing \(appDelegate.drawingPaths.count) completed paths + \(currentPath != nil ? "1" : "0") current path")
        
        // Draw completed paths
        for (index, path) in appDelegate.drawingPaths.enumerated() {
            print("🎨 Drawing completed path \(index) with \(path.points.count) points")
            drawPath(context: context, path: path)
        }
        
        // Draw current path
        if let currentPath = currentPath {
            print("🎨 Drawing current path with \(currentPath.points.count) points")
            drawPath(context: context, path: currentPath)
        }
    }
    
    private func drawPath(context: GraphicsContext, path: TestAppDelegate.DrawingPath) {
        guard !path.points.isEmpty else { return }
        
        var cgPath = Path()
        cgPath.move(to: path.points[0])
        
        for point in path.points.dropFirst() {
            cgPath.addLine(to: point)
        }
        
        let strokeStyle = getStrokeStyle(for: path.tool, strokeWidth: path.strokeWidth)
        context.stroke(cgPath, with: .color(path.color), style: strokeStyle)
    }
    
    private func getStrokeStyle(for tool: TestAppDelegate.DrawingTool, strokeWidth: Double = 5.0) -> StrokeStyle {
        switch tool {
        case .select:
            // Select tool doesn't draw, return default style
            return StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        case .pen:
            return StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        case .marker:
            return StrokeStyle(lineWidth: strokeWidth * 1.5, lineCap: .round, lineJoin: .round)
        case .laser:
            return StrokeStyle(lineWidth: strokeWidth * 0.8, lineCap: .round, lineJoin: .round)
        case .blur:
            return StrokeStyle(lineWidth: strokeWidth * 2.0, lineCap: .round, lineJoin: .round)
        case .eraser:
            return StrokeStyle(lineWidth: strokeWidth * 3.0, lineCap: .round, lineJoin: .round)
        case .shapes:
            // Shape tools use their own stroke width from shapeManager
            return StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        case .text:
            // Text tool doesn't use stroke style
            return StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        }
    }
}

// MARK: - Professional UI Components

struct StatusCard: View {
    let mode: TestAppDelegate.InteractionMode
    let tool: TestAppDelegate.DrawingTool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.tip.crop.circle.badge.plus.fill")
                    .foregroundColor(.accentColor)
                Text("Pointly Professional")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 12) {
                ModeIndicator(mode: mode)
                ToolIndicator(tool: tool)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ModeIndicator: View {
    let mode: TestAppDelegate.InteractionMode
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode.icon)
                .foregroundColor(mode.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(mode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(mode.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ToolIndicator: View {
    let tool: TestAppDelegate.DrawingTool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tool.icon)
                .foregroundColor(tool.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(tool.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tool.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct QuickActions: View {
    @ObservedObject var appDelegate: TestAppDelegate
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { appDelegate.toggleMode() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Tab")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button(action: { appDelegate.showHelp.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                    Text("H")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: { appDelegate.hideOverlay() }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                    Text("Esc")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

struct ProfessionalToolPalette: View {
    @ObservedObject var appDelegate: TestAppDelegate
    @Binding var drawingPaths: [TestAppDelegate.DrawingPath]
    
    var body: some View {
        HStack(spacing: 16) {
            // Tool buttons
            HStack(spacing: 8) {
                ForEach(Array(TestAppDelegate.DrawingTool.allCases.enumerated()), id: \.element) { index, tool in
                    ToolButton(
                        tool: tool,
                        isSelected: tool == appDelegate.currentTool,
                        shortcut: "\(index + 1)"
                    ) {
                        appDelegate.currentTool = tool
                    }
                }
            }
            .padding(.horizontal)
            
            Divider()
                .frame(height: 30)
            
            // Actions
            HStack(spacing: 8) {
                Button(action: { 
                    drawingPaths.removeAll()
                    appDelegate.shapeManager.clearAll()
                    appDelegate.textManager.clearAll()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                
                Button(action: undoLastPath) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(drawingPaths.isEmpty)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.bottom, 40)
    }
    
    private func undoLastPath() {
        if !drawingPaths.isEmpty {
            drawingPaths.removeLast()
        }
    }
}

// MARK: - Compact Tool Palettes

struct CompactToolPalette: View {
    @ObservedObject var appDelegate: TestAppDelegate
    @Binding var drawingPaths: [TestAppDelegate.DrawingPath]
    @State private var isHovered = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Tool buttons with amazing spacing
            HStack(spacing: 10) {
                ForEach(Array(TestAppDelegate.DrawingTool.allCases.enumerated()), id: \.element) { index, tool in
                    CompactToolButton(
                        tool: tool,
                        isSelected: tool == appDelegate.currentTool,
                        shortcut: "\(index + 1)"
                    ) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            appDelegate.selectDrawingTool(tool)
                        }
                    }
                }
            }
            
            // Beautiful divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.primary.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1, height: 44)
            
            // Color picker (shared for drawings and text)
            VStack(spacing: 6) {
                Text("Color")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .white.opacity(0.2), radius: 1)
                
                ColorPicker("", selection: $appDelegate.globalColor)
                    .labelsHidden()
                    .frame(width: 36, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
            }
                    
                    // Text size control (for text tool)
                    if appDelegate.currentTool == .text {
                        VStack(spacing: 6) {
                            Text("Size")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .white.opacity(0.2), radius: 1)
                            
                            HStack(spacing: 4) {
                                Button(action: {
                                    if appDelegate.textManager.fontSize > 8 {
                                        appDelegate.textManager.fontSize -= 2
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(Int(appDelegate.textManager.fontSize))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 30)
                                
                                Button(action: {
                                    if appDelegate.textManager.fontSize < 72 {
                                        appDelegate.textManager.fontSize += 2
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                    }
                    
                    // Width control (for drawing tools, not text)
                    if appDelegate.currentTool != .text {
                        VStack(spacing: 6) {
                            Text("Width")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .white.opacity(0.2), radius: 1)
                            
                            ZStack {
                                // Background track
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 100, height: 8)
                                
                                // Progress track
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: CGFloat(appDelegate.globalStrokeWidth) / 20 * 100, height: 8)
                                
                                // Thumb
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.9)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 16, height: 16)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .offset(x: CGFloat(appDelegate.globalStrokeWidth) / 20 * 100 - 50)
                            }
                            .frame(width: 100, height: 30)
                            .contentShape(Rectangle())
                            .background(Color.clear)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let progress = max(0, min(1, value.location.x / 100))
                                        appDelegate.globalStrokeWidth = Double(progress * 19 + 1)
                                        print("🎨 Width changed to: \(appDelegate.globalStrokeWidth)")
                                    }
                            )
                            .onTapGesture { location in
                                let progress = max(0, min(1, location.x / 100))
                                appDelegate.globalStrokeWidth = Double(progress * 19 + 1)
                                print("🎨 Width clicked to: \(appDelegate.globalStrokeWidth)")
                            }
                        }
                    }
                    
                    // UI Scale slider
                    VStack(spacing: 6) {
                        Text("UI")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.2), radius: 1)
                        
                        HStack(spacing: 4) {
                            Button(action: {
                                appDelegate.toolbarScale = max(0.6, appDelegate.toolbarScale - 0.1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(Int(appDelegate.toolbarScale * 100))%")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 32)
                            
                            Button(action: {
                                appDelegate.toolbarScale = min(1.2, appDelegate.toolbarScale + 0.1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    
                    // Drag handle
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(isDragging ? 0.2 : 0.1))
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    dragOffset = value.translation
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                        .help("Drag to move toolbar")
                    
                    // Action buttons with stunning design
                    HStack(spacing: 12) {
                        AwesomeActionButton(
                            icon: "trash.fill",
                            title: "Clear All",
                            color: .red,
                            isEnabled: !drawingPaths.isEmpty || !appDelegate.shapeManager.drawnShapes.isEmpty || !appDelegate.textManager.textLabels.isEmpty
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                drawingPaths.removeAll()
                                appDelegate.shapeManager.clearAll()
                                appDelegate.textManager.clearAll()
                            }
                        }
                        
                        AwesomeActionButton(
                            icon: "arrow.uturn.backward",
                            title: "Undo",
                            color: .blue,
                            isEnabled: !drawingPaths.isEmpty || !appDelegate.shapeManager.drawnShapes.isEmpty || !appDelegate.textManager.textLabels.isEmpty
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                appDelegate.performUndo()
                            }
                        }
                    }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            ZStack {
                // Main glassmorphism background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.5),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Animated shimmer effect
                if isHovered {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isHovered)
                }
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .scaleEffect((isHovered ? 1.02 : 1.0) * appDelegate.toolbarScale)
        .offset(dragOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appDelegate.toolbarScale)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func undoLastPath() {
        if !drawingPaths.isEmpty {
            drawingPaths.removeLast()
        }
    }
}

struct AwesomeActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isEnabled ? 
                            [.white, .white.opacity(0.9)] : 
                            [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? .white.opacity(0.3) : .clear, radius: 1)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isEnabled ? 
                            [.white, .white.opacity(0.9)] : 
                            [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? .white.opacity(0.2) : .clear, radius: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Main background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isEnabled ? 
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isEnabled ? 
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.2), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Glow effect when hovered
                    if isHovered && isEnabled {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.3), color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 8)
                            .scaleEffect(1.1)
                    }
                }
            )
            .shadow(
                color: isEnabled ? color.opacity(0.3) : .clear, 
                radius: isHovered ? 8 : 4, 
                x: 0, 
                y: isHovered ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // Long press action
        }
    }
}

struct CompactToolButton: View {
    let tool: TestAppDelegate.DrawingTool
    let isSelected: Bool
    let shortcut: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Glowing background effect
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tool.color.opacity(0.3), tool.color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .blur(radius: 8)
                            .scaleEffect(1.2)
                    }
                    
                    // Main icon container
                    ZStack {
                        // Background with glassmorphism
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isSelected ? 
                                LinearGradient(
                                    colors: [tool.color, tool.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected ? 
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [tool.color.opacity(0.2), tool.color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .frame(width: 50, height: 50)
                        
                        // Icon
                        Image(systemName: tool.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? 
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [tool.color, tool.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 2)
                    }
                }
                
                // Tool name with beautiful typography
                Text(tool.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isSelected ? .white.opacity(0.2) : .clear, radius: 1)
                
                // Shortcut badge
                Text(shortcut)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
            .frame(width: 70, height: 80)
            .background(
                // Outer glow effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? 
                                LinearGradient(
                                    colors: [tool.color.opacity(0.4), tool.color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) : 
                                LinearGradient(
                                    colors: [Color.clear, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : (isHovered ? 1.03 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct CompactShapePalette: View {
    @ObservedObject var shapeManager: ShapeDrawingManager
    @ObservedObject var appDelegate: TestAppDelegate
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Shape type buttons with amazing design
            HStack(spacing: 10) {
                ForEach(ShapeType.allCases, id: \.self) { shapeType in
                    AwesomeShapeButton(
                        shapeType: shapeType,
                        isSelected: shapeManager.currentShapeType == shapeType,
                        color: shapeType.color
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            shapeManager.setShapeType(shapeType)
                        }
                    }
                }
            }
            
            // Beautiful divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.primary.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1, height: 40)
            
            // Width control with stunning design
            VStack(spacing: 6) {
                Text("Width")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .white.opacity(0.2), radius: 1)
                
                ZStack {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 8)
                    
                    // Progress track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat(shapeManager.strokeWidth) / 20 * 100, height: 8)
                    
                    // Thumb
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: CGFloat(shapeManager.strokeWidth) / 20 * 100 - 50)
                }
                .frame(width: 100, height: 30)
                .contentShape(Rectangle())
                .background(Color.clear)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / 100))
                            let newWidth = Double(progress * 19 + 1)
                            shapeManager.strokeWidth = newWidth
                            appDelegate.globalStrokeWidth = newWidth
                            print("🎨 Shape width changed to: \(newWidth)")
                        }
                )
                .onTapGesture { location in
                    let progress = max(0, min(1, location.x / 100))
                    let newWidth = Double(progress * 19 + 1)
                    shapeManager.strokeWidth = newWidth
                    appDelegate.globalStrokeWidth = newWidth
                    print("🎨 Shape width clicked to: \(newWidth)")
                }
            }
            
            // Fill toggle with amazing design
            VStack(spacing: 6) {
                Text("Fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .white.opacity(0.2), radius: 1)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        shapeManager.isFilled.toggle()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                shapeManager.isFilled ? 
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 24)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .offset(x: shapeManager.isFilled ? 8 : -8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ZStack {
                // Main glassmorphism background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.6),
                                Color.black.opacity(0.4),
                                Color.black.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Animated shimmer effect
                if isHovered {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isHovered)
                }
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AwesomeShapeButton: View {
    let shapeType: ShapeType
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glowing background effect
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.4), color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .blur(radius: 6)
                            .scaleEffect(1.3)
                    }
                    
                    // Main icon container
                    ZStack {
                        // Background with glassmorphism
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                isSelected ? 
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isSelected ? 
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [color.opacity(0.3), color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .frame(width: 40, height: 40)
                        
                        // Icon
                        Image(systemName: shapeType.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? 
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 1)
                    }
                }
                
                // Shape name with beautiful typography
                Text(shapeType.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isSelected ? .white.opacity(0.2) : .clear, radius: 1)
            }
            .frame(width: 50, height: 60)
            .background(
                // Outer glow effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? 
                                LinearGradient(
                                    colors: [color.opacity(0.5), color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) : 
                                LinearGradient(
                                    colors: [Color.clear, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct VerticalToolPalette: View {
    @ObservedObject var appDelegate: TestAppDelegate
    @Binding var drawingPaths: [TestAppDelegate.DrawingPath]
    @State private var isHovered = false
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let isCompact = screenHeight < 800
            let buttonSize: CGFloat = isCompact ? 40 : 50
            let spacing: CGFloat = isCompact ? 6 : 8
            let padding: CGFloat = isCompact ? 12 : 16
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: spacing) {
                    // Tool buttons in vertical layout - responsive
                    VStack(spacing: spacing) {
                        ForEach(Array(TestAppDelegate.DrawingTool.allCases.enumerated()), id: \.element) { index, tool in
                            ResponsiveVerticalToolButton(
                                tool: tool,
                                isSelected: tool == appDelegate.currentTool,
                                shortcut: "\(index + 1)",
                                buttonSize: buttonSize,
                                isCompact: isCompact
                            ) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    appDelegate.selectDrawingTool(tool)
                                }
                            }
                        }
                    }
                    
                    // Beautiful divider - responsive
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.primary.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: buttonSize * 0.8, height: 1)
                    
                    // Action buttons in vertical layout - responsive
                    VStack(spacing: spacing) {
                        ResponsiveVerticalActionButton(
                            icon: "trash.fill",
                            title: "Clear",
                            color: .red,
                            isEnabled: !drawingPaths.isEmpty || !appDelegate.shapeManager.drawnShapes.isEmpty || !appDelegate.textManager.textLabels.isEmpty,
                            buttonSize: buttonSize,
                            isCompact: isCompact
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                drawingPaths.removeAll()
                                appDelegate.shapeManager.clearAll()
                                appDelegate.textManager.clearAll()
                            }
                        }
                        
                        ResponsiveVerticalActionButton(
                            icon: "arrow.uturn.backward",
                            title: "Undo",
                            color: .blue,
                            isEnabled: !drawingPaths.isEmpty,
                            buttonSize: buttonSize,
                            isCompact: isCompact
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if !drawingPaths.isEmpty {
                                    drawingPaths.removeLast()
                                }
                            }
            
            // UI scale control (toolbar size)
            VStack(spacing: 6) {
                Text("UI")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Slider(value: $appDelegate.toolbarScale, in: 0.6...1.0, step: 0.05)
                    .frame(width: 90)
            }
                        }
        .scaleEffect(appDelegate.toolbarScale)
        .animation(.easeInOut(duration: 0.2), value: appDelegate.toolbarScale)
                    }
                }
                .padding(.vertical, padding)
                .padding(.horizontal, padding)
            }
            .frame(maxHeight: min(screenHeight * 0.8, 600)) // Responsive height
            .background(
                ZStack {
                    // Main glassmorphism background
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.5),
                                    Color.black.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Animated shimmer effect
                    if isHovered {
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isHovered)
                    }
                }
            )
            .shadow(color: .black.opacity(0.3), radius: isCompact ? 15 : 20, x: 10, y: 0)
            .shadow(color: .black.opacity(0.1), radius: isCompact ? 3 : 5, x: 2, y: 0)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(width: 80) // Fixed width for consistency
    }
}

struct VerticalShapePalette: View {
    @ObservedObject var shapeManager: ShapeDrawingManager
    @ObservedObject var appDelegate: TestAppDelegate
    @State private var isHovered = false
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let isCompact = screenHeight < 800
            let buttonSize: CGFloat = isCompact ? 35 : 40
            let spacing: CGFloat = isCompact ? 6 : 8
            let padding: CGFloat = isCompact ? 12 : 16
            let sliderHeight: CGFloat = isCompact ? 60 : 80
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: spacing) {
                    // Shape type buttons in vertical layout - responsive
                    VStack(spacing: spacing) {
                        ForEach(ShapeType.allCases, id: \.self) { shapeType in
                            ResponsiveVerticalShapeButton(
                                shapeType: shapeType,
                                isSelected: shapeManager.currentShapeType == shapeType,
                                color: shapeType.color,
                                buttonSize: buttonSize,
                                isCompact: isCompact
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    shapeManager.setShapeType(shapeType)
                                }
                            }
                        }
                    }
                    
                    // Beautiful divider - responsive
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.primary.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: buttonSize * 0.8, height: 1)
                    
                    // Width control in vertical layout - responsive
                    VStack(spacing: 4) {
                        Text("Width")
                            .font(.system(size: isCompact ? 9 : 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.2), radius: 1)
                        
                        ZStack {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 6, height: sliderHeight)
                            
                            // Progress track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple, .pink],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 6, height: CGFloat(shapeManager.strokeWidth) / 20 * sliderHeight)
                            
                            // Thumb
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: isCompact ? 12 : 16, height: isCompact ? 12 : 16)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .offset(y: CGFloat(shapeManager.strokeWidth) / 20 * sliderHeight - sliderHeight/2)
                        }
                        .frame(width: 30, height: sliderHeight)
                        .contentShape(Rectangle())
                        .background(Color.clear)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = max(0, min(1, value.location.y / sliderHeight))
                                    let newWidth = Double(progress * 19 + 1)
                                    shapeManager.strokeWidth = newWidth
                                    appDelegate.globalStrokeWidth = newWidth
                                    print("🎨 Shape width changed to: \(newWidth)")
                                }
                        )
                        .onTapGesture { location in
                            let progress = max(0, min(1, location.y / sliderHeight))
                            let newWidth = Double(progress * 19 + 1)
                            shapeManager.strokeWidth = newWidth
                            appDelegate.globalStrokeWidth = newWidth
                            print("🎨 Shape width clicked to: \(newWidth)")
                        }
                    }
                    
                    // Fill toggle in vertical layout - responsive
                    VStack(spacing: 4) {
                        Text("Fill")
                            .font(.system(size: isCompact ? 9 : 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.2), radius: 1)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                shapeManager.isFilled.toggle()
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                                    .fill(
                                        shapeManager.isFilled ? 
                                        LinearGradient(
                                            colors: [.green, .green.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: isCompact ? 20 : 24, height: isCompact ? 30 : 40)
                                
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.9)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: isCompact ? 16 : 20, height: isCompact ? 16 : 20)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    .offset(y: shapeManager.isFilled ? (isCompact ? 6 : 8) : (isCompact ? -6 : -8))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, padding)
                .padding(.horizontal, padding)
            }
            .frame(maxHeight: min(screenHeight * 0.6, 400)) // Responsive height
            .background(
                ZStack {
                    // Main glassmorphism background
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Animated shimmer effect
                    if isHovered {
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isHovered)
                    }
                }
            )
            .shadow(color: .black.opacity(0.3), radius: isCompact ? 12 : 15, x: 10, y: 0)
            .shadow(color: .black.opacity(0.1), radius: isCompact ? 2 : 3, x: 2, y: 0)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(width: 70) // Fixed width for consistency
    }
}

struct ResponsiveVerticalToolButton: View {
    let tool: TestAppDelegate.DrawingTool
    let isSelected: Bool
    let shortcut: String
    let buttonSize: CGFloat
    let isCompact: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 2 : 4) {
                ZStack {
                    // Glowing background effect
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tool.color.opacity(0.3), tool.color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: buttonSize * 0.8, height: buttonSize * 0.8)
                            .blur(radius: isCompact ? 4 : 6)
                            .scaleEffect(1.2)
                    }
                    
                    // Main icon container
                    ZStack {
                        // Background with glassmorphism
                        RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                            .fill(
                                isSelected ? 
                                LinearGradient(
                                    colors: [tool.color, tool.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                                    .stroke(
                                        isSelected ? 
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [tool.color.opacity(0.2), tool.color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .frame(width: buttonSize, height: buttonSize)
                        
                        // Icon
                        Image(systemName: tool.icon)
                            .font(.system(size: isCompact ? 16 : 20, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? 
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [tool.color, tool.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 2)
                    }
                }
                
                // Tool name with beautiful typography - responsive
                Text(tool.displayName)
                    .font(.system(size: isCompact ? 8 : 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isSelected ? .white.opacity(0.2) : .clear, radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Shortcut badge - responsive
                Text(shortcut)
                    .font(.system(size: isCompact ? 6 : 8, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, isCompact ? 3 : 4)
                    .padding(.vertical, isCompact ? 1 : 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
            .frame(width: buttonSize + 10, height: isCompact ? 60 : 80)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : (isHovered ? 1.03 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ResponsiveVerticalShapeButton: View {
    let shapeType: ShapeType
    let isSelected: Bool
    let color: Color
    let buttonSize: CGFloat
    let isCompact: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 2 : 4) {
                ZStack {
                    // Glowing background effect
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.4), color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: buttonSize * 0.9, height: buttonSize * 0.9)
                            .blur(radius: isCompact ? 4 : 6)
                            .scaleEffect(1.3)
                    }
                    
                    // Main icon container
                    ZStack {
                        // Background with glassmorphism
                        RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                            .fill(
                                isSelected ? 
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                                    .stroke(
                                        isSelected ? 
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [color.opacity(0.3), color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .frame(width: buttonSize, height: buttonSize)
                        
                        // Icon
                        Image(systemName: shapeType.icon)
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? 
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 1)
                    }
                }
                
                // Shape name with beautiful typography - responsive
                Text(shapeType.displayName)
                    .font(.system(size: isCompact ? 7 : 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isSelected ? .white.opacity(0.2) : .clear, radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: buttonSize + 10, height: isCompact ? 50 : 60)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ResponsiveVerticalActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let isEnabled: Bool
    let buttonSize: CGFloat
    let isCompact: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 2 : 4) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isEnabled ? 
                            [.white, .white.opacity(0.9)] : 
                            [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? .white.opacity(0.3) : .clear, radius: 1)
                
                Text(title)
                    .font(.system(size: isCompact ? 7 : 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isEnabled ? 
                            [.white, .white.opacity(0.9)] : 
                            [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? .white.opacity(0.2) : .clear, radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, isCompact ? 6 : 8)
            .background(
                ZStack {
                    // Main background
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                        .fill(
                            isEnabled ? 
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                                .stroke(
                                    isEnabled ? 
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.2), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Glow effect when hovered
                    if isHovered && isEnabled {
                        RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.3), color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: isCompact ? 4 : 6)
                            .scaleEffect(1.1)
                    }
                }
            )
            .shadow(
                color: isEnabled ? color.opacity(0.3) : .clear, 
                radius: isHovered ? (isCompact ? 4 : 6) : (isCompact ? 2 : 3), 
                x: 0, 
                y: isHovered ? (isCompact ? 2 : 3) : (isCompact ? 1 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // Long press action
        }
    }
}

struct VerticalToolButton: View {
    let tool: TestAppDelegate.DrawingTool
    let isSelected: Bool
    let shortcut: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glowing background effect
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tool.color.opacity(0.3), tool.color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .blur(radius: 6)
                            .scaleEffect(1.2)
                    }
                    
                    // Main icon container
                    ZStack {
                        // Background with glassmorphism
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isSelected ? 
                                LinearGradient(
                                    colors: [tool.color, tool.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isSelected ? 
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [tool.color.opacity(0.2), tool.color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .frame(width: 50, height: 50)
                        
                        // Icon
                        Image(systemName: tool.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? 
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [tool.color, tool.color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 2)
                    }
                }
                
                // Tool name with beautiful typography
                Text(tool.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isSelected ? .white.opacity(0.2) : .clear, radius: 1)
                
                // Shortcut badge
                Text(shortcut)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
            .frame(width: 60, height: 80)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : (isHovered ? 1.03 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct VerticalShapeButton: View {
    let shapeType: ShapeType
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glowing background effect
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.4), color.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .blur(radius: 6)
                            .scaleEffect(1.3)
                    }
                    
                    // Main icon container
                    ZStack {
                        // Background with glassmorphism
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                isSelected ? 
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isSelected ? 
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [color.opacity(0.3), color.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .frame(width: 40, height: 40)
                        
                        // Icon
                        Image(systemName: shapeType.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? 
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 1)
                    }
                }
                
                // Shape name with beautiful typography
                Text(shapeType.displayName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isSelected ? .white.opacity(0.2) : .clear, radius: 1)
            }
            .frame(width: 50, height: 60)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct VerticalActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isEnabled ? 
                            [.white, .white.opacity(0.9)] : 
                            [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? .white.opacity(0.3) : .clear, radius: 1)
                
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isEnabled ? 
                            [.white, .white.opacity(0.9)] : 
                            [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isEnabled ? .white.opacity(0.2) : .clear, radius: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Main background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isEnabled ? 
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isEnabled ? 
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.2), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Glow effect when hovered
                    if isHovered && isEnabled {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.3), color.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 6)
                            .scaleEffect(1.1)
                    }
                }
            )
            .shadow(
                color: isEnabled ? color.opacity(0.3) : .clear, 
                radius: isHovered ? 6 : 3, 
                x: 0, 
                y: isHovered ? 3 : 1
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // Long press action
        }
    }
}

struct CompactShapeButton: View {
    let shapeType: ShapeType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: shapeType.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : shapeType.color)
                .frame(width: 28, height: 24)
                .background(
                    isSelected ? shapeType.color : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(shapeType.color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ToolButton: View {
    let tool: TestAppDelegate.DrawingTool
    let isSelected: Bool
    let shortcut: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tool.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : tool.color)
                
                Text(tool.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(shortcut)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, height: 80)
            .background(
                isSelected ? tool.color : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tool.color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct KeyboardShortcutsOverlay: View {
    @ObservedObject var appDelegate: TestAppDelegate
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Keyboard Shortcuts")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    ShortcutRow(keys: "⌘⌃P", description: "Toggle overlay")
                    ShortcutRow(keys: "⌘⌃H", description: "Show/hide this help")
                    ShortcutRow(keys: "Tab", description: "Switch Draw/Interact mode")
                    ShortcutRow(keys: "Esc", description: "Hide overlay")
                    ShortcutRow(keys: "H", description: "Toggle help overlay")
                    
                    Divider()
                    
                    Text("Drawing Tools")
                        .font(.headline)
                        .padding(.top)
                    
                    ForEach(Array(TestAppDelegate.DrawingTool.allCases.enumerated()), id: \.element) { index, tool in
                        ShortcutRow(keys: "\(index + 1)", description: tool.displayName)
                    }
                }
                
                Button("Got it!") {
                    appDelegate.showHelp = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            Spacer()
        }
        .background(.black.opacity(0.3))
    }
}

struct ShortcutRow: View {
    let keys: String
    let description: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .frame(minWidth: 50)
            
            Text(description)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Help Window

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pointly Professional - Complete Guide")
                    .font(.title)
                    .fontWeight(.bold)
                
                HelpSection(
                    title: "Getting Started",
                    content: """
                    1. Press ⌘⌃P to activate the overlay
                    2. Use Tab to switch between Draw and Interact modes
                    3. In Draw mode, select tools and start annotating
                    4. In Interact mode, clicks pass through to apps below
                    5. Press Escape to hide the overlay anytime
                    """
                )
                
                HelpSection(
                    title: "Keyboard Shortcuts",
                    content: """
                    Global Shortcuts (work anywhere):
                    • ⌘⌃P - Toggle overlay
                    • ⌘⌃H - Show help window
                    
                    Overlay Shortcuts (when overlay is active):
                    • Tab - Switch Draw/Interact mode
                    • Esc - Hide overlay
                    • H - Toggle help overlay
                    • ⌘Z - Undo last drawing action
                    • ⌘⇧Z - Redo last undone action
                    • 1-6 - Select drawing tools (Select, Pen, Marker, Laser, Blur, Eraser)
                    """
                )
                
                HelpSection(
                    title: "Drawing Tools",
                    content: """
                    Available Tools:
                    1. Select - Select and move objects (text labels and shapes)
                    2. Pen - Precise drawing with smooth lines
                    3. Marker - Textured strokes with realistic blending
                    4. Laser Pointer - Animated pointer with 3-second fade
                    5. Blur Brush - Screen-space blur for emphasis
                    6. Eraser - Remove annotations cleanly
                    7. Shapes - Draw shapes (Rectangle, Ellipse, Arrow, Line)
                    8. Text - Add text labels to your annotations
                    
                    When Shapes tool is selected, use the bottom palette to choose specific shape types.
                    """
                )
                
                HelpSection(
                    title: "Interaction Modes",
                    content: """
                    Draw Mode:
                    • Overlay captures all input
                    • Drawing tools are active
                    • Perfect for annotations and presentations
                    
                    Interact Mode:
                    • Clicks pass through to apps below
                    • You can interact with underlying applications
                    • Overlay becomes transparent to input
                    """
                )
                
                HelpSection(
                    title: "Pro Tips",
                    content: """
                    • Use number keys (1-6) for quick tool switching
                    • The menu bar icon shows current mode and tool
                    • Click the menu bar icon for quick access to all features
                    • Use Clear button to remove all drawings
                    • Use Undo to remove the last drawn path
                    • Text tool: First click enables creation, second click creates text field
                    • Select tool: Drag a rectangle to select multiple objects, then drag to move them
                    """
                )
            }
            .padding()
        }
    }
}

struct HelpSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Helper Classes

class HelpWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - Test Settings View

struct TestSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🎨 Pointly Professional")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Beautiful, modern annotation tool")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "✅", title: "Professional UI/UX", description: "Beautiful, modern interface")
                FeatureRow(icon: "✅", title: "Advanced Tools", description: "Pen, Marker, Laser, Blur, Eraser")
                FeatureRow(icon: "✅", title: "Smart Modes", description: "Draw and Interact modes")
                FeatureRow(icon: "✅", title: "Keyboard Shortcuts", description: "Complete shortcut system")
                FeatureRow(icon: "✅", title: "Help System", description: "Comprehensive documentation")
            }
            
            Divider()
            
            Text("Press ⌘⌃P to start using Pointly!")
                .font(.headline)
                .foregroundColor(.accentColor)
        }
        .padding(30)
        .frame(width: 500, height: 400)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}