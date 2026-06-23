import SwiftUI
import MetalKit

struct OverlayView: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    @State private var showToolbar = true
    @State private var toolbarPosition = CGPoint(x: 200, y: 100)
    @State private var isDrawing = false
    @State private var canvasSize = CGSize.zero
    @State private var metalRenderer: MetalRenderer?

    @State private var showModeIndicator = false
    @State private var modeIndicatorOpacity = 0.0

    @State private var textInputPosition: CGPoint? = nil
    @State private var pendingText = ""

    var body: some View {
        ZStack {
            // Drawing / interact layer
            Color.clear
                .contentShape(Rectangle())
                .gesture(interactionMode.currentMode == .draw ? drawingGesture : nil)
                .allowsHitTesting(interactionMode.currentMode == .draw)
                // Double-tap to toggle toolbar — only in interact mode to avoid draw conflicts
                .onTapGesture(count: 2) {
                    guard interactionMode.currentMode == .interact else { return }
                    withAnimation(.easeInOut(duration: 0.3)) { showToolbar.toggle() }
                }

            // Canvas
            if let renderer = metalRenderer {
                MetalDrawingCanvas(state: drawingState, renderer: renderer)
            } else {
                DrawingCanvas(state: drawingState)
            }

            // Mode indicator HUD
            if showModeIndicator {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ModeIndicatorView(mode: interactionMode.currentMode)
                            .opacity(modeIndicatorOpacity)
                        Spacer()
                    }
                    Spacer().frame(height: 100)
                }
            }

            // Text input overlay
            if let pos = textInputPosition {
                TextInputOverlay(
                    text: $pendingText,
                    color: drawingState.selectedColor,
                    fontSize: max(14, drawingState.strokeThickness * 4),
                    onCommit: {
                        drawingState.addTextElement(at: pos, text: pendingText)
                        textInputPosition = nil
                        pendingText = ""
                    },
                    onCancel: {
                        textInputPosition = nil
                        pendingText = ""
                    }
                )
                .position(pos)
            }

            // Floating toolbar
            if showToolbar {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingToolbar(
                            drawingState: drawingState,
                            interactionMode: interactionMode,
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
        .onAppear {
            drawingState.loadAnnotations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .interactionModeChanged)) { notification in
            handleModeChange(notification)
        }
        .onKeyPress(.tab) {
            interactionMode.toggleMode()
            return .handled
        }
        .onKeyPress(.escape) {
            if textInputPosition != nil {
                textInputPosition = nil
                pendingText = ""
            } else if isDrawing {
                // Cancel in-progress stroke before switching mode
                drawingState.cancelCurrentStroke()
                isDrawing = false
                interactionMode.switchTo(mode: .interact)
            } else if interactionMode.currentMode == .draw {
                interactionMode.switchTo(mode: .interact)
            }
            return .handled
        }
    }

    // MARK: - Drawing Gesture

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard interactionMode.currentMode == .draw else { return }

                // Eraser: directly erase at cursor position
                if drawingState.selectedTool == .eraser {
                    drawingState.eraseAt(value.location)
                    return
                }

                // Text tool: wait for tap-end, not drag
                if drawingState.selectedTool == .text { return }

                if !isDrawing {
                    isDrawing = true
                    drawingState.startDrawing(at: value.location)
                } else {
                    drawingState.continueDrawing(to: value.location)
                }
            }
            .onEnded { value in
                guard interactionMode.currentMode == .draw else { return }

                if drawingState.selectedTool == .eraser {
                    return
                }

                if drawingState.selectedTool == .text {
                    let dist = hypot(value.translation.width, value.translation.height)
                    if dist < 8 {
                        textInputPosition = value.startLocation
                        pendingText = ""
                    }
                    return
                }

                drawingState.finishStroke()
                isDrawing = false
            }
    }

    // MARK: - Metal Init

    private func initializeMetalRenderer() {
        do {
            metalRenderer = try MetalRenderer()
        } catch {
            // Metal unavailable — falls back to Core Graphics DrawingCanvas
        }
    }

    // MARK: - Mode Change Handler

    private func handleModeChange(_ notification: Notification) {
        showModeIndicator = true
        withAnimation(.easeInOut(duration: 0.3)) { modeIndicatorOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) { modeIndicatorOpacity = 0.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showModeIndicator = false }
        }
        updateCursor()
    }

    private func updateCursor() {
        switch interactionMode.currentMode {
        case .interact: NSCursor.arrow.set()
        case .draw:
            if drawingState.selectedTool == .text {
                NSCursor.iBeam.set()
            } else {
                NSCursor.crosshair.set()
            }
        }
    }
}

// MARK: - Text Input Overlay

struct TextInputOverlay: View {
    @Binding var text: String
    let color: Color
    let fontSize: CGFloat
    let onCommit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(color)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.6), lineWidth: 1))
            )
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onSubmit { onCommit() }
    }
}

// MARK: - Metal Drawing Canvas

struct MetalDrawingCanvas: View {
    @ObservedObject var state: DrawingState
    let renderer: MetalRenderer

    var body: some View {
        MetalView(drawingState: state, renderer: renderer)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

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

    func makeCoordinator() -> Coordinator { Coordinator(renderer: renderer, drawingState: drawingState) }

    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: MetalRenderer
        var drawingState: DrawingState

        init(renderer: MetalRenderer, drawingState: DrawingState) {
            self.renderer = renderer
            self.drawingState = drawingState
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }
            renderer.render(elements: drawingState.elements,
                            to: drawable,
                            viewportSize: CGSize(width: view.drawableSize.width, height: view.drawableSize.height))
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let hideOverlay = Notification.Name("HideOverlay")
}

