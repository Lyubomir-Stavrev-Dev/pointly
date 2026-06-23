import SwiftUI

struct FloatingToolbar: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager   // injected, not owned
    @Binding var position: CGPoint

    @State private var isDragging = false
    @State private var dragStartPosition: CGPoint = .zero         // fixed: capture start once
    @StateObject private var exportManager = ExportManager()

    private let toolbarWidth: CGFloat = 520
    private let toolbarHeight: CGFloat = 90

    var body: some View {
        VStack(spacing: 6) {
            // Row 1 — mode toggle
            HStack(spacing: 6) {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    interactionMode.toggleMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: interactionMode.currentMode.systemImage)
                            .font(.system(size: 13))
                        Text(interactionMode.currentMode.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(interactionMode.currentMode == .draw
                                  ? Color.accentColor
                                  : Color.secondary.opacity(0.2))
                    )
                    .foregroundColor(interactionMode.currentMode == .draw ? .white : .primary)
                }
                .buttonStyle(.plain)

                Spacer()

                if interactionMode.isTransitioning {
                    ProgressView().scaleEffect(0.5)
                }
            }

            // Row 2 — tools
            HStack(spacing: 6) {
                toolButton(.pen)
                toolButton(.highlighter)
                toolButton(.eraser)

                divider()

                toolButton(.marker)
                toolButton(.blurBrush)
                toolButton(.laserPointer)

                divider()

                toolButton(.rectangle)
                toolButton(.ellipse)
                toolButton(.arrow)
                toolButton(.line)

                divider()

                toolButton(.text)

                divider()

                // Undo / Redo
                Button { drawingState.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15))
                        .foregroundColor(drawingState.canUndo ? .primary : .secondary.opacity(0.4))
                        .frame(width: 26, height: 26)
                }
                .disabled(!drawingState.canUndo)
                .buttonStyle(.plain)

                Button { drawingState.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15))
                        .foregroundColor(drawingState.canRedo ? .primary : .secondary.opacity(0.4))
                        .frame(width: 26, height: 26)
                }
                .disabled(!drawingState.canRedo)
                .buttonStyle(.plain)

                divider()

                // Color picker
                ColorPicker("", selection: $drawingState.selectedColor)
                    .frame(width: 26, height: 26)
                    .disabled(!drawingState.selectedTool.supportsColor)

                // Thickness
                if drawingState.selectedTool.supportsThickness {
                    HStack(spacing: 2) {
                        Text("\(Int(drawingState.strokeThickness))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 14)
                        Slider(value: $drawingState.strokeThickness, in: 1...10, step: 1)
                            .frame(width: 46)
                    }
                }

                // Fill toggle (shapes only)
                if drawingState.selectedTool == .rectangle || drawingState.selectedTool == .ellipse {
                    Button { drawingState.isFilled.toggle() } label: {
                        Image(systemName: drawingState.isFilled ? "square.fill" : "square")
                            .font(.system(size: 15))
                            .foregroundColor(drawingState.isFilled ? .accentColor : .primary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle fill")
                }

                divider()

                // Export
                Menu {
                    Button("Export as PNG") {
                        exportManager.showExportPanel(for: drawingState, format: .png,
                            size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080))
                    }
                    Button("Export as PDF") {
                        exportManager.showExportPanel(for: drawingState, format: .pdf,
                            size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080))
                    }
                    Button("Export as JPEG") {
                        exportManager.showExportPanel(for: drawingState, format: .jpeg,
                            size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080))
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 26)
                }
                .menuStyle(.borderlessButton)

                // Clear
                Button { drawingState.clearAll() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
        .frame(width: toolbarWidth)
        .fixedSize()                          // let height expand naturally
        .gesture(dragGesture)
        .onAppear { constrainToScreen() }
    }

    // MARK: - Tool Button

    private func toolButton(_ tool: DrawingTool) -> some View {
        let selected = drawingState.selectedTool == tool
        return Button {
            drawingState.selectedTool = tool
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .white : .primary)
                if [.marker, .blurBrush, .laserPointer].contains(tool) {
                    Text(tool.displayName)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(selected ? .white : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 30, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                            .opacity(selected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .help(tool.description)
    }

    @ViewBuilder
    private func divider() -> some View {
        Divider().frame(height: 22)
    }

    // MARK: - Drag — fixed: record start position once per drag

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartPosition = position
                }
                position = CGPoint(
                    x: dragStartPosition.x + value.translation.width,
                    y: dragStartPosition.y + value.translation.height
                )
                constrainToScreen()
            }
            .onEnded { _ in isDragging = false }
    }

    private func constrainToScreen() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let hw = toolbarWidth / 2
        let hh: CGFloat = 50  // approximate half-height for clamping
        position.x = max(f.minX + hw, min(f.maxX - hw, position.x))
        position.y = max(f.minY + hh, min(f.maxY - hh, position.y))
    }
}

