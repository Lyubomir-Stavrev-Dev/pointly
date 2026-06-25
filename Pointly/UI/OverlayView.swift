import SwiftUI
import MetalKit

struct OverlayView: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    @State private var isDrawing = false
    @State private var canvasSize = CGSize.zero
    @State private var metalRenderer: MetalRenderer?

    @State private var showModeIndicator = false
    @State private var modeIndicatorOpacity = 0.0

    @State private var textInputPosition: CGPoint? = nil
    @State private var pendingText = ""

    // Selection / move state
    private enum SelAction { case moving(last: CGPoint), rubberBanding }
    @State private var selAction: SelAction? = nil

    // Resize state (stored in OverlayView so all handles share it)
    @State private var resizeInitialBox: CGRect? = nil
    @State private var resizeSnapshot: [(UUID, [CGPoint])]? = nil
    @State private var isDraggingHandle = false

    // Spotlight state
    @State private var spotlightPosition: CGPoint? = nil

    var body: some View {
        ZStack {
            // Erase covers for Cut & Move — rendered at canvas level so they reliably
            // hide real app content beneath the transparent canvas window.
            ForEach(drawingState.liftedCovers) { cover in
                Group {
                    if let img = cover.image {
                        Image(nsImage: img).resizable()
                    } else {
                        Rectangle().fill(cover.fillColor)
                    }
                }
                .frame(width: cover.rect.width, height: cover.rect.height)
                .position(x: cover.rect.midX, y: cover.rect.midY)
                .allowsHitTesting(false)
            }

            // Gesture capture layer + spotlight mouse tracking
            Color.clear
                .contentShape(Rectangle())
                .gesture(interactionMode.currentMode == .draw ? mainGesture : nil)
                .allowsHitTesting(interactionMode.currentMode == .draw)
                .onContinuousHover { phase in
                    if case .active(let loc) = phase {
                        spotlightPosition = loc
                    }
                }

            // Canvas
            if let renderer = metalRenderer {
                MetalDrawingCanvas(state: drawingState, renderer: renderer)
            } else {
                DrawingCanvas(state: drawingState)
            }

            // Mode HUD
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

            // Text input
            if let pos = textInputPosition {
                TextInputOverlay(
                    text: $pendingText,
                    color: drawingState.selectedColor,
                    fontSize: max(14, drawingState.strokeThickness * 4),
                    onCommit: {
                        drawingState.addTextElement(at: pos, text: pendingText)
                        textInputPosition = nil
                        pendingText = ""
                        drawingState.isTextInputActive = false
                    },
                    onCancel: {
                        textInputPosition = nil
                        pendingText = ""
                        drawingState.isTextInputActive = false
                    }
                )
                .position(pos)
            }

            // Selection visuals (rubber band + bounding box border) — no hit testing
            selectionVisuals
                .allowsHitTesting(false)

            // Resize handles — interactive, on top (hidden for text-only selections)
            if (drawingState.selectedTool == .select || drawingState.selectedTool == .cutMove),
               let box = drawingState.selectedBoundingBox,
               !drawingState.selectedElementsAreAllText {
                resizeHandles(for: box)
            }

            // Spotlight overlay — rendered above canvas, below toolbar (separate window)
            if drawingState.selectedTool == .spotlight,
               let pos = spotlightPosition {
                SpotlightOverlay(center: pos,
                                 radius: CGFloat(drawingState.strokeThickness) * 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { canvasSize = geo.size; initializeMetalRenderer() }
                    .onChange(of: geo.size) { canvasSize = $0 }
            }
        )
        .onAppear { drawingState.loadAnnotations() }
        .onReceive(NotificationCenter.default.publisher(for: .interactionModeChanged)) { handleModeChange($0) }
        .onChange(of: drawingState.selectedTool) { tool in
            if tool != .select && tool != .cutMove { drawingState.clearSelection() }
            if tool == .cursor { NSCursor.arrow.set() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelTextInput)) { _ in
            textInputPosition = nil
            pendingText = ""
            drawingState.isTextInputActive = false
        }
    }

    // MARK: - Unified gesture

    private var mainGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let isSelectionTool = drawingState.selectedTool == .select
                                   || drawingState.selectedTool == .cutMove
                if isSelectionTool {
                    handleSelectionChanged(value)
                } else {
                    handleDrawingChanged(value)
                }
            }
            .onEnded { value in
                let isSelectionTool = drawingState.selectedTool == .select
                                   || drawingState.selectedTool == .cutMove
                if isSelectionTool {
                    handleSelectionEnded(value)
                } else {
                    handleDrawingEnded(value)
                }
            }
    }

    // MARK: - Drawing gesture handlers

    private func handleDrawingChanged(_ value: DragGesture.Value) {
        guard interactionMode.currentMode == .draw else { return }

        if drawingState.selectedTool == .spotlight {
            spotlightPosition = value.location
            return
        }
        if drawingState.selectedTool == .eraser {
            drawingState.eraseAt(value.location)
            return
        }
        if drawingState.selectedTool == .text { return }

        if !isDrawing {
            isDrawing = true
            drawingState.startDrawing(at: value.location)
        } else {
            drawingState.continueDrawing(to: value.location)
        }
    }

    private func handleDrawingEnded(_ value: DragGesture.Value) {
        guard interactionMode.currentMode == .draw else { return }
        if drawingState.selectedTool == .eraser { return }
        if drawingState.selectedTool == .text {
            if hypot(value.translation.width, value.translation.height) < 8 {
                textInputPosition = value.startLocation
                pendingText = ""
                drawingState.isTextInputActive = true
            }
            return
        }
        drawingState.finishStroke()
        isDrawing = false
    }

    // MARK: - Selection gesture handlers

    private func handleSelectionChanged(_ value: DragGesture.Value) {
        if isDraggingHandle { return }

        if selAction == nil {
            let startPt = value.startLocation
            let isCutMove = drawingState.selectedTool == .cutMove
            if let box = drawingState.selectedBoundingBox, box.contains(startPt) {
                selAction = .moving(last: startPt)
            } else if !isCutMove, let hit = drawingState.hitTest(at: startPt) {
                if !drawingState.selectedElementIDs.contains(hit.id) {
                    drawingState.selectElement(id: hit.id)
                }
                selAction = .moving(last: startPt)
            } else {
                drawingState.clearSelection()
                drawingState.selectionRubberBand = CGRect(origin: startPt, size: .zero)
                selAction = .rubberBanding
            }
        }

        switch selAction {
        case .moving(let last):
            let delta = CGSize(width: value.location.x - last.x,
                               height: value.location.y - last.y)
            drawingState.moveSelected(by: delta)
            selAction = .moving(last: value.location)
        case .rubberBanding:
            let s = value.startLocation, c = value.location
            drawingState.selectionRubberBand = CGRect(
                x: min(s.x, c.x), y: min(s.y, c.y),
                width: abs(c.x - s.x), height: abs(c.y - s.y))
        default: break
        }
    }

    private func handleSelectionEnded(_ value: DragGesture.Value) {
        if isDraggingHandle { return }
        if case .rubberBanding = selAction {
            if drawingState.selectedTool == .cutMove {
                if let r = drawingState.selectionRubberBand, r.width > 10, r.height > 10 {
                    NotificationCenter.default.post(name: .captureAndLift, object: r)
                }
                drawingState.selectionRubberBand = nil
            } else {
                if let r = drawingState.selectionRubberBand { drawingState.selectElements(in: r) }
                drawingState.selectionRubberBand = nil
            }
        }
        selAction = nil
    }

    // MARK: - Selection visuals

    @ViewBuilder
    private var selectionVisuals: some View {
        // Rubber band rectangle
        if let r = drawingState.selectionRubberBand {
            Rectangle()
                .stroke(Color.accentColor.opacity(0.8),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .background(Color.accentColor.opacity(0.05))
                .frame(width: max(r.width, 1), height: max(r.height, 1))
                .position(x: r.midX, y: r.midY)
        }

        // Bounding box of selected elements
        if drawingState.selectedTool == .select,
           let box = drawingState.selectedBoundingBox {
            Rectangle()
                .stroke(Color.accentColor,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .frame(width: box.width + 2, height: box.height + 2)
                .position(x: box.midX, y: box.midY)
        }
    }

    // MARK: - Resize handles

    private enum HandlePos: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        func point(in box: CGRect) -> CGPoint {
            switch self {
            case .topLeft:     return CGPoint(x: box.minX, y: box.minY)
            case .topRight:    return CGPoint(x: box.maxX, y: box.minY)
            case .bottomLeft:  return CGPoint(x: box.minX, y: box.maxY)
            case .bottomRight: return CGPoint(x: box.maxX, y: box.maxY)
            }
        }
    }

    @ViewBuilder
    private func resizeHandles(for box: CGRect) -> some View {
        ForEach(HandlePos.allCases, id: \.self) { handle in
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                .frame(width: 11, height: 11)
                .contentShape(Circle().inset(by: -10))
                .position(handle.point(in: box))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingHandle = true
                            if resizeInitialBox == nil {
                                resizeInitialBox = box
                                resizeSnapshot = drawingState.elements
                                    .filter { drawingState.selectedElementIDs.contains($0.id) }
                                    .map { ($0.id, $0.points) }
                            }
                            guard let initBox = resizeInitialBox,
                                  let snap = resizeSnapshot else { return }
                            let newBox = newBoxForHandle(handle, startBox: initBox,
                                                        translation: value.translation)
                            drawingState.resizeFromSnapshot(snap, from: initBox, to: newBox)
                        }
                        .onEnded { _ in
                            resizeInitialBox = nil
                            resizeSnapshot = nil
                            isDraggingHandle = false
                        }
                )
        }
    }

    private func newBoxForHandle(_ handle: HandlePos, startBox: CGRect,
                                  translation: CGSize) -> CGRect {
        var minX = startBox.minX, minY = startBox.minY
        var maxX = startBox.maxX, maxY = startBox.maxY
        switch handle {
        case .topLeft:     minX += translation.width; minY += translation.height
        case .topRight:    maxX += translation.width; minY += translation.height
        case .bottomLeft:  minX += translation.width; maxY += translation.height
        case .bottomRight: maxX += translation.width; maxY += translation.height
        }
        if maxX - minX < 10 { maxX = minX + 10 }
        if maxY - minY < 10 { maxY = minY + 10 }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Metal init

    private func initializeMetalRenderer() {
        do { metalRenderer = try MetalRenderer() } catch {}
    }

    // MARK: - Mode change

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
            switch drawingState.selectedTool {
            case .text:      NSCursor.iBeam.set()
            case .select:    NSCursor.arrow.set()
            case .spotlight: NSCursor.crosshair.set()
            default:         NSCursor.crosshair.set()
            }
        }
    }
}

// MARK: - Spotlight Overlay

private struct SpotlightOverlay: View {
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            // Dark vignette over the entire canvas
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.72))
            )
            // Erase a soft circle at the cursor position so the content shows through
            ctx.blendMode = .destinationOut
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white,              location: 0.0),
                        .init(color: .white.opacity(0.9), location: 0.6),
                        .init(color: .clear,              location: 1.0)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
        .compositingGroup()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
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
                            viewportSize: CGSize(width: view.drawableSize.width,
                                                height: view.drawableSize.height))
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let hideOverlay   = Notification.Name("HideOverlay")
    static let captureAndLift = Notification.Name("CaptureAndLift")
}
