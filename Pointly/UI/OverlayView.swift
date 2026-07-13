import SwiftUI

struct OverlayView: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    /// The display this canvas window lives on — elements are stamped with it
    /// and each canvas renders only its own display's elements.
    var displayID: CGDirectDisplayID = 0
    @State private var isDrawing = false
    @State private var canvasSize = CGSize.zero

    @State private var showModeIndicator = false
    @State private var modeIndicatorOpacity = 0.0
    @State private var modeHUDWorkItem: DispatchWorkItem? = nil

    @State private var hintTool: DrawingTool? = nil
    @State private var hintKey: String = ""
    @State private var hintVisible = false
    @State private var hintWorkItem: DispatchWorkItem? = nil

    @State private var textInputPosition: CGPoint? = nil
    @State private var pendingText = ""
    @State private var pendingCalloutTarget: CGPoint? = nil   // set while typing a callout label
    @State private var calloutTarget: CGPoint? = nil          // anchored after 1st click, box follows cursor
    @State private var ghostPos: CGPoint = .zero              // live cursor while placing the callout box
    @State private var editingElementID: UUID? = nil          // element being re-edited (text/callout)
    @State private var editColor: Color? = nil
    @State private var editThickness: CGFloat? = nil
    @State private var didMoveSelection = false               // real drag vs a click, for undo + edit

    // Selection / move state
    private enum SelAction { case moving(last: CGPoint), rubberBanding }
    @State private var selAction: SelAction? = nil

    // Resize state (stored in OverlayView so all handles share it)
    @State private var resizeInitialBox: CGRect? = nil
    @State private var resizeSnapshot: [(UUID, [CGPoint])]? = nil
    @State private var isDraggingHandle = false
    @State private var isEraserStrokeActive = false

    // Spotlight state
    @State private var spotlightPosition: CGPoint? = nil

    var body: some View {
        ZStack {
            // Whiteboard background — full-screen dark grid canvas
            if drawingState.whiteboardMode {
                WhiteboardBackground()
                    .transition(.opacity)
            }

            // Erase covers for Cut & Move — rendered at canvas level so they reliably
            // hide real app content beneath the transparent canvas window.
            ForEach(drawingState.liftedCovers.filter { $0.displayID == nil || $0.displayID == displayID }) { cover in
                Rectangle()
                    .fill(cover.fillColor)
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
                        if calloutTarget != nil { ghostPos = loc }
                    }
                }

            // Canvas
            DrawingCanvas(state: drawingState, displayID: displayID)

            // Ghost callout preview while placing the box (between the two clicks)
            if let target = calloutTarget {
                CalloutGhostView(target: target, boxOrigin: ghostPos,
                                 color: drawingState.selectedColor,
                                 thickness: drawingState.strokeThickness)
                    .allowsHitTesting(false)
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

            // Live callout box+leader behind the field, kept until Enter commits.
            if let pos = textInputPosition, let target = pendingCalloutTarget {
                CalloutGhostView(target: target, boxOrigin: pos,
                                 color: editColor ?? drawingState.selectedColor,
                                 thickness: editThickness ?? drawingState.strokeThickness,
                                 text: pendingText.isEmpty ? " " : pendingText,
                                 dashed: false)
                    .allowsHitTesting(false)
            }

            // Text input — anchored so the field's TEXT top-left sits at `pos`,
            // matching drawText's .topLeading anchor (a centered .position(pos)
            // made committed text jump down-right by half the field size).
            if let pos = textInputPosition {
                let isCallout = pendingCalloutTarget != nil
                ZStack(alignment: .topLeading) {
                    Color.clear.allowsHitTesting(false)
                    TextInputOverlay(
                        text: $pendingText,
                        color: isCallout ? .white : (editColor ?? drawingState.selectedColor),
                        fontSize: max(14, (editThickness ?? drawingState.strokeThickness) * 4),
                        showBackground: !isCallout,   // callout draws its own box behind
                        onCommit: { commitPendingText() },
                        onCancel: { resetTextEntry() }
                    )
                    // Callout: sit the text inside its box padding. Plain text: top-left anchor.
                    .offset(x: isCallout ? pos.x + 11 : pos.x - 6,
                            y: isCallout ? pos.y + 8 : pos.y - 3)
                }
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

            // Keystroke hint HUD
            if hintVisible, let tool = hintTool {
                VStack {
                    Spacer()
                    KeystrokeHintView(tool: tool, key: hintKey)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity
                        ))
                    Spacer().frame(height: 110)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
            }
        )
        .onAppear { drawingState.loadAnnotations() }
        .onContinuousHover { phase in
            guard case .active = phase,
                  interactionMode.currentMode == .draw else { return }
            ToolCursor.cursor(for: drawingState.selectedTool).set()
        }
        .onReceive(NotificationCenter.default.publisher(for: .interactionModeChanged)) { handleModeChange($0) }
        .onChange(of: drawingState.selectedTool) { _, tool in
            if tool != .select && tool != .cutMove { drawingState.clearSelection() }
            // Commit in-progress text instead of leaving the field floating
            // (empty text is dropped by addTextElement's guard).
            commitPendingText()
            // Reset any in-flight gesture — tool hotkeys fire mid-drag, and a
            // half-finished stroke/move otherwise corrupts the next gesture
            // (ghost strokes, un-undoable erases, stuck rubber band).
            if isDrawing {
                drawingState.cancelCurrentStroke()
                isDrawing = false
            }
            isEraserStrokeActive = false
            if case .moving = selAction { drawingState.commitTransform() }
            selAction = nil
            drawingState.selectionRubberBand = nil
            resizeInitialBox = nil
            resizeSnapshot = nil
            isDraggingHandle = false
            updateCursor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelTextInput)) { _ in
            resetTextEntry()
            calloutTarget = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .keystrokeHint)) { note in
            showKeystrokeHint(note)
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

    /// Commit whatever text input is open — updating an element being edited,
    /// or adding a new callout / text label. No-op when nothing is being typed.
    private func commitPendingText() {
        guard let pos = textInputPosition else { return }
        if let editID = editingElementID {
            drawingState.setText(pendingText, forElementID: editID)
        } else if let target = pendingCalloutTarget {
            drawingState.addTextCallout(target: target, boxOrigin: pos, text: pendingText)
        } else {
            drawingState.addTextElement(at: pos, text: pendingText)
        }
        resetTextEntry()
    }

    private func resetTextEntry() {
        textInputPosition = nil
        pendingText = ""
        pendingCalloutTarget = nil
        editingElementID = nil
        editColor = nil
        editThickness = nil
        drawingState.isTextInputActive = false
    }

    /// Re-open an existing text/callout element for editing (from the select tool).
    private func beginEditing(_ e: DrawingElement) {
        commitPendingText()
        editingElementID = e.id
        editColor = e.color
        editThickness = e.thickness
        pendingText = e.text ?? ""
        pendingCalloutTarget = e.tool == .textCallout ? e.points.first : nil
        textInputPosition = (e.tool == .textCallout && e.points.count >= 2) ? e.points[1] : e.points.first
        drawingState.clearSelection()
        drawingState.isTextInputActive = true
    }

    private func handleDrawingChanged(_ value: DragGesture.Value) {
        guard interactionMode.currentMode == .draw else { return }
        drawingState.activeDisplayID = displayID

        if drawingState.selectedTool == .spotlight {
            spotlightPosition = value.location
            return
        }
        if drawingState.selectedTool == .eraser {
            if !isEraserStrokeActive {
                drawingState.beginEraseStroke()
                isEraserStrokeActive = true
            }
            drawingState.eraseAt(value.location)
            return
        }
        if drawingState.selectedTool == .text { return }
        if drawingState.selectedTool == .stepBadge { return }    // click places on gesture end
        if drawingState.selectedTool == .textCallout { return }  // drag defines target→box on end

        if !isDrawing {
            isDrawing = true
            drawingState.startDrawing(at: value.location)
        } else {
            drawingState.continueDrawing(to: value.location)
        }
    }

    private func handleDrawingEnded(_ value: DragGesture.Value) {
        guard interactionMode.currentMode == .draw else { return }
        if drawingState.selectedTool == .eraser {
            isEraserStrokeActive = false
            return
        }
        if drawingState.selectedTool == .stepBadge {
            if hypot(value.translation.width, value.translation.height) < 8 {
                drawingState.addStepBadge(at: value.startLocation)
            }
            return
        }
        if drawingState.selectedTool == .textCallout {
            let click = value.startLocation
            if let target = calloutTarget {
                // Second click: drop the box here and start typing (leader → target).
                pendingCalloutTarget = target
                textInputPosition = click
                pendingText = ""
                editingElementID = nil; editColor = nil; editThickness = nil
                drawingState.isTextInputActive = true
                calloutTarget = nil
            } else {
                // First click: anchor the target; a ghost box now follows the cursor.
                commitPendingText()
                calloutTarget = click
                ghostPos = click
            }
            return
        }
        if drawingState.selectedTool == .text {
            if hypot(value.translation.width, value.translation.height) < 8 {
                // Commit any in-progress text before opening a new input —
                // click-away used to silently discard what was typed.
                commitPendingText()
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
        drawingState.activeDisplayID = displayID

        if selAction == nil {
            let startPt = value.startLocation
            didMoveSelection = false
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
            // Only treat as a move once the pointer actually travels — a pure
            // click stays a click (→ edit text/callout) and pushes no undo.
            guard hypot(value.translation.width, value.translation.height) > 4 else { break }
            if !didMoveSelection { drawingState.beginTransform(); didMoveSelection = true }
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
        if case .moving = selAction {
            if didMoveSelection {
                drawingState.commitTransform()
            } else if drawingState.selectedTool == .select,
                      let hit = drawingState.hitTest(at: value.startLocation),
                      hit.tool == .text || hit.tool == .textCallout {
                // Pure click on a text/callout → edit it in place.
                beginEditing(hit)
            }
        }
        if case .rubberBanding = selAction {
            if drawingState.selectedTool == .cutMove {
                if let r = drawingState.selectionRubberBand, r.width > 10, r.height > 10 {
                    // Pass the source display explicitly — the handler used to
                    // guess via NSScreen.main and could capture the wrong screen.
                    NotificationCenter.default.post(name: .captureAndLift, object: nil,
                        userInfo: ["rect": r, "displayID": displayID])
                }
                drawingState.selectionRubberBand = nil
            } else {
                if let r = drawingState.selectionRubberBand { drawingState.selectElements(in: r) }
                drawingState.selectionRubberBand = nil
            }
        }
        selAction = nil
        didMoveSelection = false
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
                                drawingState.beginTransform()   // one undo snapshot per resize drag
                            }
                            guard let initBox = resizeInitialBox,
                                  let snap = resizeSnapshot else { return }
                            let newBox = newBoxForHandle(handle, startBox: initBox,
                                                        translation: value.translation)
                            drawingState.resizeFromSnapshot(snap, from: initBox, to: newBox)
                        }
                        .onEnded { _ in
                            if resizeInitialBox != nil { drawingState.commitTransform() }
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

    // MARK: - Mode change

    private func handleModeChange(_ notification: Notification) {
        // Cancellable like the keystroke-hint HUD — rapid mode toggles used to
        // leave stale timers that hid the NEW indicator early.
        modeHUDWorkItem?.cancel()
        showModeIndicator = true
        withAnimation(.easeInOut(duration: 0.3)) { modeIndicatorOpacity = 1.0 }
        let fade = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) { modeIndicatorOpacity = 0.0 }
            let hide = DispatchWorkItem { showModeIndicator = false }
            modeHUDWorkItem = hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: hide)
        }
        modeHUDWorkItem = fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: fade)
        updateCursor()
    }

    private func updateCursor() {
        switch interactionMode.currentMode {
        case .interact: NSCursor.arrow.set()
        case .draw:     ToolCursor.cursor(for: drawingState.selectedTool).set()
        }
    }

    // MARK: - Keystroke hint

    private func showKeystrokeHint(_ note: Notification) {
        guard let tool = note.userInfo?["tool"] as? DrawingTool,
              let key  = note.userInfo?["key"]  as? String else { return }
        hintTool = tool
        hintKey  = key
        hintWorkItem?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { hintVisible = true }
        let item = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) { hintVisible = false }
        }
        hintWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: item)
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
    var showBackground: Bool = true   // off when a callout box is drawn behind
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
                // Dark glass so the typed text reads on ANY screen background,
                // with a single restrained brand-orange accent (no gradient).
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.03, green: 0.03, blue: 0.07).opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(red: 0.96, green: 0.39, blue: 0.30).opacity(0.75), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.96, green: 0.39, blue: 0.30).opacity(0.30), radius: 7)
                    .shadow(color: .black.opacity(0.45), radius: 5, y: 2)
                    .opacity(showBackground ? 1 : 0)
            )
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onSubmit { onCommit() }
            .onExitCommand { onCancel() }   // Escape cancels directly from the field
    }
}

// MARK: - Callout ghost preview (between the two placement clicks)

private struct CalloutGhostView: View {
    let target: CGPoint
    let boxOrigin: CGPoint
    let color: Color
    let thickness: CGFloat
    var text: String = "Label"      // live text so the box grows while typing
    var dashed: Bool = true         // dashed = ghost placing; solid = active typing

    var body: some View {
        Canvas { ctx, _ in
            let box = DrawingElement.calloutBox(origin: boxOrigin, text: text, thickness: thickness)
            let anchor = CGPoint(x: min(max(target.x, box.minX), box.maxX),
                                 y: min(max(target.y, box.minY), box.maxY))
            let style = StrokeStyle(lineWidth: max(1.5, thickness * 0.6), lineCap: .round,
                                    dash: dashed ? [5, 4] : [])
            var leader = Path(); leader.move(to: target); leader.addLine(to: anchor)
            ctx.stroke(leader, with: .color(color.opacity(dashed ? 0.5 : 0.9)), style: style)
            let dot = 3 + thickness * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: target.x - dot, y: target.y - dot, width: dot * 2, height: dot * 2)),
                     with: .color(color.opacity(dashed ? 0.6 : 1)))
            let boxPath = Path(roundedRect: box, cornerRadius: 8)
            ctx.fill(boxPath, with: .color(Color(red: 0.03, green: 0.03, blue: 0.07).opacity(dashed ? 0.5 : 0.9)))
            ctx.stroke(boxPath, with: .color(color.opacity(dashed ? 0.6 : 1)),
                       style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [5, 4] : []))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Whiteboard Background

private struct WhiteboardBackground: View {
    private let bg    = Color(red: 0.05, green: 0.05, blue: 0.10)
    private let grid  = Color(red: 0.20, green: 0.20, blue: 0.40)
    private let step: CGFloat = 50

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))

            var lines = Path()
            var x: CGFloat = 0
            while x <= size.width  { lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = 0
            while y <= size.height { lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            ctx.stroke(lines, with: .color(grid.opacity(0.25)), lineWidth: 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Keystroke Hint HUD

private struct KeystrokeHintView: View {
    let tool: DrawingTool
    let key: String

    private let orange = Color(red: 0.96, green: 0.45, blue: 0.08)
    private let pink   = Color(red: 0.91, green: 0.16, blue: 0.60)

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LinearGradient(
                    colors: [orange, pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(tool.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(key)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: orange.opacity(0.25), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let hideOverlay    = Notification.Name("HideOverlay")
    static let captureAndLift = Notification.Name("CaptureAndLift")
    static let keystrokeHint  = Notification.Name("KeystrokeHint")
}
