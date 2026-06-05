import AppKit
import Combine
import SwiftUI

/// Manages the interaction mode state and overlay behavior
/// 
/// **Design Decision**: Separate manager for interaction modes to enable:
/// - Clean separation between drawing and pass-through logic
/// - Easy extension for future modes (presentation, collaboration, etc.)
/// - Centralized state management for UI consistency
///
/// **Architecture**: Publisher-based reactive updates to UI components
class InteractionModeManager: ObservableObject {
    
    // MARK: - Interaction Modes
    
    /// Available interaction modes for the overlay
    enum InteractionMode: String, CaseIterable {
        case interact = "interact"  // Pass-through mode - clicks go to underlying apps
        case draw = "draw"         // Drawing mode - overlay captures all input
        
        var displayName: String {
            switch self {
            case .interact: return "Interact"
            case .draw: return "Draw"
            }
        }
        
        var description: String {
            switch self {
            case .interact: return "Click through to underlying applications"
            case .draw: return "Capture input for drawing and annotation"
            }
        }
        
        var systemImage: String {
            switch self {
            case .interact: return "hand.point.up.left"
            case .draw: return "pencil"
            }
        }
    }
    
    // MARK: - Published State
    
    /// Current interaction mode
    @Published private(set) var currentMode: InteractionMode = .draw
    
    /// Whether mode switching is available (some contexts may lock mode)
    @Published var canSwitchMode: Bool = true
    
    /// Visual feedback for mode transitions
    @Published var isTransitioning: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private weak var overlayWindow: NSWindow?
    
    // MARK: - Initialization
    
    init() {
        setupModeTransitionAnimations()
    }
    
    // MARK: - Public Methods
    
    /// Set the overlay window to manage
    /// - Parameter window: The overlay window to control
    func setOverlayWindow(_ window: NSWindow) {
        self.overlayWindow = window
        applyModeToWindow()
    }
    
    /// Switch to a specific interaction mode
    /// - Parameter mode: Target interaction mode
    func switchTo(mode: InteractionMode) {
        guard canSwitchMode && mode != currentMode else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isTransitioning = true
        }
        
        // Delay actual mode switch for smooth visual transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentMode = mode
            self.applyModeToWindow()
            
            // Complete transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isTransitioning = false
                }
            }
        }
        
        // Send haptic feedback on supported devices
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        // Log mode change for debugging
        print("🔄 Interaction mode changed: \(currentMode.displayName)")
    }
    
    /// Toggle between interact and draw modes
    func toggleMode() {
        let newMode: InteractionMode = currentMode == .interact ? .draw : .interact
        switchTo(mode: newMode)
    }
    
    /// Temporarily switch to a mode (e.g., for modifier key hold)
    /// - Parameters:
    ///   - mode: Temporary mode to switch to
    ///   - completion: Called when temporary mode ends
    func temporaryMode(_ mode: InteractionMode, completion: @escaping () -> Void) {
        let originalMode = currentMode
        switchTo(mode: mode)
        
        // Return to original mode after a delay or external trigger
        // This will be enhanced in future phases for modifier key handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.switchTo(mode: originalMode)
            completion()
        }
    }
    
    // MARK: - Private Methods
    
    /// Apply the current mode settings to the overlay window
    private func applyModeToWindow() {
        guard let window = overlayWindow else { return }
        
        switch currentMode {
        case .interact:
            // Pass-through mode: ignore mouse events
            window.ignoresMouseEvents = true
            window.level = .floating  // Lower level so it doesn't interfere
            
        case .draw:
            // Drawing mode: capture all input
            window.ignoresMouseEvents = false
            window.level = .screenSaver  // High level to capture input
        }
        
        // Update window appearance based on mode
        updateWindowAppearance()
    }
    
    /// Update visual appearance based on current mode
    private func updateWindowAppearance() {
        // This will be enhanced with visual mode indicators
        // For now, we'll use subtle background tinting
        
        // Post notification for UI components to update
        NotificationCenter.default.post(
            name: .interactionModeChanged,
            object: self,
            userInfo: ["mode": currentMode]
        )
    }
    
    /// Setup smooth animations for mode transitions
    private func setupModeTransitionAnimations() {
        // Monitor mode changes for smooth transitions
        $currentMode
            .dropFirst()  // Skip initial value
            .sink { [weak self] newMode in
                self?.handleModeChange(to: newMode)
            }
            .store(in: &cancellables)
    }
    
    /// Handle mode change with appropriate feedback
    /// - Parameter mode: New interaction mode
    private func handleModeChange(to mode: InteractionMode) {
        // Show temporary visual indicator
        showModeIndicator(for: mode)
        
        // Update menu bar if available
        updateMenuBarIndicator(for: mode)
    }
    
    /// Show temporary visual mode indicator
    /// - Parameter mode: Mode to indicate
    private func showModeIndicator(for mode: InteractionMode) {
        // Create temporary HUD indicator
        let indicator = ModeIndicatorView(mode: mode)
        
        // This will be implemented as an overlay in future phases
        // For now, we'll use console logging
        print("📱 Mode Indicator: \(mode.displayName) - \(mode.description)")
    }
    
    /// Update menu bar icon to reflect current mode
    /// - Parameter mode: Current mode
    private func updateMenuBarIndicator(for mode: InteractionMode) {
        // Post notification for AppDelegate to update menu bar icon
        NotificationCenter.default.post(
            name: .updateMenuBarIcon,
            object: nil,
            userInfo: ["mode": mode]
        )
    }
}

// MARK: - Mode Indicator View

/// Temporary visual indicator for mode changes
struct ModeIndicatorView: View {
    let mode: InteractionModeManager.InteractionMode
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 16, weight: .medium))
            
            Text(mode.displayName)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
        .foregroundColor(.primary)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when interaction mode changes
    static let interactionModeChanged = Notification.Name("InteractionModeChanged")
    
    /// Posted when menu bar icon should be updated
    static let updateMenuBarIcon = Notification.Name("UpdateMenuBarIcon")
}

// MARK: - Global Hotkey Integration

extension InteractionModeManager {
    
    /// Register global hotkeys for mode switching
    /// - Parameter hotkeyManager: Global hotkey manager instance
    func registerModeHotkeys(with hotkeyManager: GlobalHotkeyManager) {
        // Register Tab key for mode toggle (common in professional tools)
        hotkeyManager.registerHotkey(
            keyCode: 48,  // Tab key
            modifiers: []
        ) { [weak self] in
            self?.toggleMode()
        }
        
        // Register Escape for quick switch to interact mode
        hotkeyManager.registerHotkey(
            keyCode: 53,  // Escape key
            modifiers: []
        ) { [weak self] in
            if self?.currentMode == .draw {
                self?.switchTo(mode: .interact)
            }
        }
    }
}

// MARK: - Architecture Notes

/*
 
 ## Design Decisions:
 
 1. **Separate Manager Class**: Keeps interaction logic isolated and testable
 2. **Reactive Updates**: Uses Combine for clean UI updates
 3. **Window-Level Control**: Manages NSWindow properties directly for performance
 4. **Extensible Modes**: Easy to add presentation, collaboration modes later
 5. **Visual Feedback**: Built-in support for mode indicators and transitions
 
 ## Performance Considerations:
 
 - Mode switching is immediate (no rendering delays)
 - Window property changes are atomic
 - Minimal overhead in interact mode (pass-through)
 
 ## Future Extensions:
 
 - Modifier key temporary modes (hold E for eraser)
 - Context-aware mode switching
 - Multi-monitor mode synchronization
 - Profile-based default modes
 
 ## Risks & Limitations:
 
 - Window level changes may conflict with other overlay apps
 - Some apps may not work well with pass-through mode
 - Accessibility tools might interfere with input capture
 
 */
