import SwiftUI
import AppKit

struct FloatingToolbar: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager

    @State private var isExpanded = false
    @StateObject private var exportManager = ExportManager()

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            modeButton
                .padding(.top, 6)

            divider()

            // Drawing tools — 2 columns
            sectionLabel("DRAW")
            toolGrid2(left: { regularToolButton(.select) },
                      right: { regularToolButton(.cursor) })
            toolGrid([
                (.pen,         false), (.highlighter, false),
                (.marker,      false), (.blurBrush,   false),
                (.eraser,      false), (.text,        false),
                (.laserPointer,false), (.spotlight,   false),
            ])

            divider()

            // Lines — 2 columns
            sectionLabel("LINES")
            toolGrid([
                (.arrow, false), (.line, false),
            ])

            divider()

            // Shapes — outline then filled, paired
            sectionLabel("SHAPES")
            shapePairGrid([
                (.rectangle, .rectangle),
                (.ellipse,   .ellipse),
                (.triangle,  .triangle),
                (.diamond,   .diamond),
            ])

            divider()

            // Color picker
            ColorPicker("", selection: $drawingState.selectedColor)
                .labelsHidden()
                .frame(width: 32, height: 32)
                .disabled(!drawingState.selectedTool.supportsColor)
                .opacity(drawingState.selectedTool.supportsColor ? 1 : 0.35)
                .padding(.vertical, 6)
                .help("Stroke color")

            divider()

            // Undo / Redo
            toolGrid2(
                left: {
                    iconButton(icon: "arrow.uturn.backward",
                               tint: drawingState.canUndo ? .primary : .secondary.opacity(0.3),
                               help: "Undo") { drawingState.undo() }
                        .disabled(!drawingState.canUndo)
                },
                right: {
                    iconButton(icon: "arrow.uturn.forward",
                               tint: drawingState.canRedo ? .primary : .secondary.opacity(0.3),
                               help: "Redo") { drawingState.redo() }
                        .disabled(!drawingState.canRedo)
                }
            )

            // Export / Clear
            toolGrid2(
                left: { exportMenuButton },
                right: {
                    iconButton(icon: "trash", tint: .red, help: "Clear all") {
                        drawingState.clearAll()
                    }
                }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .fixedSize()
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 3.5) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 22, height: 2.5)
            }
        }
        .frame(width: 72, height: 28)
        .contentShape(Rectangle())
        .overlay(WindowDragHandle())
        .help("Drag to move")
    }

    // MARK: - Mode Button

    private var modeButton: some View {
        Button { interactionMode.toggleMode() } label: {
            HStack(spacing: 6) {
                Image(systemName: interactionMode.currentMode.systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(interactionMode.currentMode.displayName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(interactionMode.currentMode == .draw
                          ? Color.accentColor
                          : Color.secondary.opacity(0.15))
            )
            .foregroundColor(interactionMode.currentMode == .draw ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help("Toggle Draw / Interact (Tab)")
    }

    // MARK: - Select Tool Button

    private var selectToolButton: some View {
        let selected = drawingState.selectedTool == .select
        return Button {
            drawingState.selectedTool = .select
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lasso")
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                Text("Select")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .foregroundColor(selected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .help("Select, move, and resize annotations (Lasso)")
    }

    // MARK: - Section label

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.0)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Tool Grid (regular tools, 2 columns)

    @ViewBuilder
    private func toolGrid(_ tools: [(DrawingTool, Bool)]) -> some View {
        let rows = stride(from: 0, to: tools.count, by: 2).map {
            Array(tools[$0 ..< min($0 + 2, tools.count)])
        }
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { ri in
                HStack(spacing: 4) {
                    ForEach(rows[ri].indices, id: \.self) { ci in
                        let (tool, _) = rows[ri][ci]
                        regularToolButton(tool)
                    }
                    if rows[ri].count == 1 { Spacer() }
                }
            }
        }
    }

    // MARK: - Shape Pair Grid (outline left, filled right)

    @ViewBuilder
    private func shapePairGrid(_ pairs: [(DrawingTool, DrawingTool)]) -> some View {
        VStack(spacing: 4) {
            ForEach(pairs.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    shapeToolButton(pairs[i].0, filled: false)
                    shapeToolButton(pairs[i].1, filled: true)
                }
            }
        }
    }

    // MARK: - Regular tool button

    @ViewBuilder
    private func regularToolButton(_ tool: DrawingTool) -> some View {
        let selected = drawingState.selectedTool == tool && !tool.isShape
        Button {
            drawingState.selectedTool = tool
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tool.displayName)
    }

    // MARK: - Shape tool button (outline or filled)

    @ViewBuilder
    private func shapeToolButton(_ tool: DrawingTool, filled: Bool) -> some View {
        let selected = drawingState.selectedTool == tool && drawingState.isFilled == filled
        let icon = filled ? tool.systemImage + ".fill" : tool.systemImage
        Button {
            drawingState.selectedTool = tool
            drawingState.isFilled = filled
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tool.displayName + (filled ? " (filled)" : " (outline)"))
    }

    // MARK: - Icon button

    private func iconButton(icon: String, tint: Color, help helpText: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    // MARK: - Two-column row helper

    @ViewBuilder
    private func toolGrid2<L: View, R: View>(
        @ViewBuilder left: () -> L,
        @ViewBuilder right: () -> R
    ) -> some View {
        HStack(spacing: 4) {
            left()
            right()
        }
    }

    // MARK: - Thickness Stepper

    private var thicknessStepper: some View {
        HStack(spacing: 0) {
            Button {
                drawingState.strokeThickness = max(1, drawingState.strokeThickness - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 32)
            }
            .buttonStyle(.plain)

            Text("\(Int(drawingState.strokeThickness))")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 32)

            Button {
                drawingState.strokeThickness = min(10, drawingState.strokeThickness + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 32)
            }
            .buttonStyle(.plain)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
        .opacity(drawingState.selectedTool.supportsThickness ? 1 : 0.35)
        .disabled(!drawingState.selectedTool.supportsThickness)
        .help("Stroke thickness")
    }

    // MARK: - Divider

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    // MARK: - Export Menu

    private var exportMenuButton: some View {
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
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
        }
        .menuStyle(.borderlessButton)
        .help("Export canvas")
    }
}

// MARK: - WindowDragHandle

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}

    class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
