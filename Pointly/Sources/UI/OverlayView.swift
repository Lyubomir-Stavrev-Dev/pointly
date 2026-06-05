import SwiftUI

/// Main overlay view that handles drawing and toolbar display
@available(macOS 13.0, *)
struct OverlayView: View {
    @StateObject private var drawingState = DrawingState()
    @State private var showToolbar = true
    @State private var toolbarPosition = CGPoint(x: 100, y: 100)
    @State private var isDrawing = false
    
    var body: some View {
        ZStack {
            // Transparent background that captures mouse events
            Color.clear
                .contentShape(Rectangle())
                .gesture(drawingGesture)
            
            // Drawing canvas
            DrawingCanvas(state: drawingState)
            
            // Floating toolbar
            if showToolbar {
                FloatingToolbar(
                    drawingState: drawingState,
                    position: $toolbarPosition
                )
                .position(toolbarPosition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.keyboardDidBecomeFirstResponderNotification)) { _ in
            // Handle ESC key through notification or alternative method
        }
    }
    
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDrawing {
                    isDrawing = true
                    drawingState.startDrawing(at: value.location)
                } else {
                    drawingState.continueDrawing(to: value.location)
                }
            }
            .onEnded { value in
                drawingState.finishStroke()
                isDrawing = false
            }
    }
    
    private func hideOverlay() {
        // TODO: Communicate with OverlayWindowManager to hide overlay
        // This might need to be passed through environment or delegate
    }
}

#Preview {
    OverlayView()
        .frame(width: 800, height: 600)
        .background(Color.black.opacity(0.1))
}
