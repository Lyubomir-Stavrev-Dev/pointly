import SwiftUI
import MetalKit

/// Main overlay view that handles drawing and toolbar display
/// 
/// **Phase 2.1 Enhancement**: Integrated interaction modes and Metal rendering
@available(macOS 13.0, *)
struct OverlayView: View {
    @StateObject private var drawingState = DrawingState()
    @StateObject private var interactionMode = InteractionModeManager()
    @State private var showToolbar = true
    @State private var toolbarPosition = CGPoint(x: 200, y: 100)
    @State private var isDrawing = false
    @State private var canvasSize = CGSize.zero
    @State private var metalRenderer: MetalRenderer?
    
    // Interaction mode visual feedback
    @State private var showModeIndicator = false
    @State private var modeIndicatorOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Transparent background that captures mouse events
            Color.clear
                .contentShape(Rectangle())
                .gesture(interactionMode.currentMode == .draw ? drawingGesture : nil)
                .allowsHitTesting(interactionMode.currentMode == .draw)
            
            // Drawing canvas with Metal rendering
            if let renderer = metalRenderer {
                MetalDrawingCanvas(state: drawingState, renderer: renderer)
            } else {
                DrawingCanvas(state: drawingState)
            }
            
            // Mode indicator (shows temporarily when switching modes)
            if showModeIndicator {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ModeIndicatorView(mode: interactionMode.currentMode)
                            .opacity(modeIndicatorOpacity)
                        Spacer()
                    }
                    Spacer()
                        .frame(height: 100)  // Position above toolbar
                }
            }
            
            // Floating toolbar
            if showToolbar {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingToolbar(
                            drawingState: drawingState,
                            position: $toolbarPosition
                        )
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        canvasSize = geometry.size
                        initializeMetalRenderer()
                    }
                    .onChange(of: geometry.size) { newSize in
                        canvasSize = newSize
                    }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .interactionModeChanged)) { notification in
            handleModeChange(notification)
        }
        .onTapGesture(count: 2) {
            // Double-tap to toggle toolbar
            withAnimation(.easeInOut(duration: 0.3)) {
                showToolbar.toggle()
            }
        }
        .onKeyPress(.tab) {
            // Tab key to toggle interaction mode
            interactionMode.toggleMode()
            return .handled
        }
        .onKeyPress(.escape) {
            // Escape key to switch to interact mode
            if interactionMode.currentMode == .draw {
                interactionMode.switchTo(mode: .interact)
            }
            return .handled
        }
    }
    
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Only process drawing in draw mode
                guard interactionMode.currentMode == .draw else { return }
                
                if !isDrawing {
                    isDrawing = true
                    drawingState.startDrawing(at: value.location)
                } else {
                    drawingState.continueDrawing(to: value.location)
                }
            }
            .onEnded { value in
                guard interactionMode.currentMode == .draw else { return }
                
                drawingState.finishStroke()
                isDrawing = false
            }
    }
    
    // MARK: - Metal Rendering Setup
    
    private func initializeMetalRenderer() {
        do {
            metalRenderer = try MetalRenderer()
            print("✅ Metal renderer initialized successfully")
        } catch {
            print("⚠️ Metal renderer failed to initialize: \(error)")
            print("📱 Falling back to Core Graphics rendering")
            // Fallback to standard Canvas rendering
        }
    }
    
    // MARK: - Mode Change Handling
    
    private func handleModeChange(_ notification: Notification) {
        guard let mode = notification.userInfo?["mode"] as? InteractionModeManager.InteractionMode else { return }
        
        // Show mode indicator temporarily
        showModeIndicator = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            modeIndicatorOpacity = 1.0
        }
        
        // Hide indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                modeIndicatorOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showModeIndicator = false
            }
        }
        
        // Update cursor appearance based on mode
        updateCursorForMode(mode)
    }
    
    private func updateCursorForMode(_ mode: InteractionModeManager.InteractionMode) {
        switch mode {
        case .interact:
            NSCursor.arrow.set()
        case .draw:
            NSCursor.crosshair.set()
        }
    }
    
    private func hideOverlay() {
        // Communicate with OverlayWindowManager to hide overlay
        NotificationCenter.default.post(
            name: .hideOverlay,
            object: nil
        )
    }
}

// MARK: - Metal Drawing Canvas

/// Metal-accelerated drawing canvas for high-performance rendering
struct MetalDrawingCanvas: View {
    @ObservedObject var state: DrawingState
    let renderer: MetalRenderer
    
    var body: some View {
        MetalView(drawingState: state, renderer: renderer)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

/// UIViewRepresentable wrapper for Metal rendering
struct MetalView: NSViewRepresentable {
    @ObservedObject var drawingState: DrawingState
    let renderer: MetalRenderer
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = renderer.targetFrameRate
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.layer?.isOpaque = false
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.drawingState = drawingState
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer, drawingState: drawingState)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: MetalRenderer
        var drawingState: DrawingState
        
        init(renderer: MetalRenderer, drawingState: DrawingState) {
            self.renderer = renderer
            self.drawingState = drawingState
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }
            
            let viewportSize = CGSize(width: view.drawableSize.width, height: view.drawableSize.height)
            
            // Render using Metal
            renderer.render(
                elements: drawingState.elements,
                to: drawable,
                viewportSize: viewportSize
            )
        }
    }
}

// MARK: - Additional Notifications

extension Notification.Name {
    /// Posted when overlay should be hidden
    static let hideOverlay = Notification.Name("HideOverlay")
}
}

#Preview {
    OverlayView()
        .frame(width: 800, height: 600)
        .background(Color.black.opacity(0.1))
}
