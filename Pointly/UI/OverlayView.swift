import SwiftUI
import MetalKit

@available(macOS 13.0, *)
struct OverlayView: View {
    @StateObject private var drawingState = DrawingState()
    @StateObject private var interactionMode = InteractionModeManager()
    @State private var showToolbar = true
    @State private var toolbarPosition = CGPoint(x: 200, y: 100)
    @State private var isDrawing = false
    @State private var canvasSize = CGSize.zero
    @State private var metalRenderer: MetalRenderer?

    // Mode indicator
    @State private var showModeIndicator = false
    @State private var modeIndicatorOpacity = 0.0

    // Text tool state
    @State private var textInputPosition: CGPoint? = nil
    @State private var pendingText = ""

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(interactionMode.currentMode == .draw ? drawingGesture : nil)
                .allowsHitTesting(interactionMode.currentMode == .draw)

            if let renderer = metalRenderer {
                MetalDrawingCanvas(state: drawingState, renderer: renderer)
            } else {
                DrawingCanvas(state: drawingState)
            }

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
                        .frame(height: 100)
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
        .onAppear {
            drawingState.loadAnnotations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .interactionModeChanged)) { notification in
            handleModeChange(notification)
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showToolbar.toggle()
            }
        }
        .onKeyPress(.tab) {
            interactionMode.toggleMode()
            return .handled
        }
        .onKeyPress(.escape) {
            if textInputPosition != nil {
                textInputPosition = nil
                pendingText = ""
            } else if interactionMode.currentMode == .draw {
                interactionMode.switchTo(mode: .interact)
            }
            return .handled
        }
    }

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard interactionMode.currentMode == .draw else { return }
                // Text tool: don't draw strokes
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
                if drawingState.selectedTool == .text {
                    // Show text input on tap (minimal drag)
                    let dist = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
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

    private func initializeMetalRenderer() {
        do {
            metalRenderer = try MetalRenderer()
            print("✅ Metal renderer initialized")
        } catch {
            print("⚠️ Metal renderer unavailable, using Core Graphics")
        }
    }

    private func handleModeChange(_ notification: Notification) {
        guard let mode = notification.userInfo?["mode"] as? InteractionModeManager.InteractionMode else { return }
        showModeIndicator = true
        withAnimation(.easeInOut(duration: 0.3)) { modeIndicatorOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) { modeIndicatorOpacity = 0.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showModeIndicator = false }
        }
        updateCursorForMode(mode)
    }

    private func updateCursorForMode(_ mode: InteractionModeManager.InteractionMode) {
        switch mode {
        case .interact: NSCursor.arrow.set()
        case .draw:     NSCursor.crosshair.set()
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
            let viewportSize = CGSize(width: view.drawableSize.width, height: view.drawableSize.height)
            renderer.render(elements: drawingState.elements, to: drawable, viewportSize: viewportSize)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let hideOverlay = Notification.Name("HideOverlay")
}

#Preview {
    OverlayView()
        .frame(width: 800, height: 600)
        .background(Color.black.opacity(0.1))
}
