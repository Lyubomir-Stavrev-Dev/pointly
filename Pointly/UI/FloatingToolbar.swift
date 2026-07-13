import SwiftUI
import AppKit

// MARK: - Brand gradient (toolbar-local copy)

private let brandGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let panelTint = Color(red: 0.06, green: 0.06, blue: 0.14)

private struct VisualEffectBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 22
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = cornerRadius
        v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct FloatingToolbar: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    @ObservedObject private var pro = ProManager.shared

    @State private var isExpanded = false
    @State private var isHoveringModeButton = false
    @State private var hoverMinimize = false
    @State private var hoverExport   = false
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
                (.dotPen,      false), (.cutMove,     false),
                (.fadingPen,   false), (.stepBadge,   false),
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

            // Color palette
            colorPaletteView
                .disabled(!drawingState.selectedTool.supportsColor)
                .opacity(drawingState.selectedTool.supportsColor ? 1 : 0.25)

            divider()

            // Undo / Redo
            toolGrid2(
                left: {
                    iconButton(
                        icon: "arrow.uturn.backward",
                        tint: drawingState.canUndo ? .white : .white.opacity(0.2),
                        help: "Undo",
                        keys: "⌘Z"
                    ) { drawingState.undo() }
                    .disabled(!drawingState.canUndo)
                },
                right: {
                    let redoActive = drawingState.canRedo || !drawingState.liftedCovers.isEmpty
                    iconButton(
                        icon: "arrow.uturn.forward",
                        tint: redoActive ? .white : .white.opacity(0.2),
                        help: "Redo",
                        keys: "⌘⇧Z"
                    ) { drawingState.redo() }
                    .disabled(!redoActive)
                }
            )

            // Export / Clear
            toolGrid2(
                left: { exportMenuButton },
                right: {
                    iconButton(icon: "trash", tint: Color(hex: "#F4644D") ?? .red,
                               help: "Clear all", keys: "⌘⌫") {
                        drawingState.clearAll()
                    }
                }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            ZStack {
                VisualEffectBackground()
                panelTint.opacity(0.28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
        )
        .overlay(alignment: .bottom) {
            let isInteract = interactionMode.currentMode != .draw
            if isInteract {
                brandGradient
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .shadow(color: (Color(hex: "#E9458C") ?? .pink).opacity(0.9), radius: 10, x: 0, y: 2)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .bottom)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: interactionMode.currentMode)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .fixedSize()
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        ZStack {
            // Drag lines — centred in the row
            VStack(spacing: 3.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 22, height: 2.5)
                }
            }
            .overlay(WindowDragHandle())

            // Minimize button — top-right corner
            HStack {
                Spacer()
                Button { interactionMode.switchTo(mode: .interact) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(hoverMinimize ? 0.75 : 0.35))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(hoverMinimize ? 0.18 : 0.08)))
                        .scaleEffect(hoverMinimize ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.14), value: hoverMinimize)
                }
                .buttonStyle(.plain)
                .onHover { hoverMinimize = $0 }
                .toolTooltip("Minimize", keys: "⌘⎋")
            }
        }
        .frame(width: 72, height: 28)
        .contentShape(Rectangle())
    }

    // MARK: - Mode Button

    private var modeButton: some View {
        let isDrawMode = interactionMode.currentMode == .draw
        // On hover, preview the destination mode so the user knows what the click does.
        let previewMode = isHoveringModeButton
        let icon = previewMode
            ? InteractionModeManager.InteractionMode.interact.systemImage
            : interactionMode.currentMode.systemImage
        let label = previewMode
            ? InteractionModeManager.InteractionMode.interact.displayName
            : interactionMode.currentMode.displayName

        return Button { interactionMode.toggleMode() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .foregroundColor(.white.opacity(previewMode ? 0.7 : 1.0))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDrawMode && !previewMode
                          ? AnyShapeStyle(brandGradient)
                          : AnyShapeStyle(Color.white.opacity(previewMode ? 0.06 : 0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDrawMode && !previewMode
                                    ? AnyShapeStyle(Color.clear)
                                    : AnyShapeStyle(Color.white.opacity(0.15)),
                                lineWidth: 0.8
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: previewMode)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringModeButton = $0 }
        .toolTooltip("Switch to \(isDrawMode ? "Interact" : "Draw") mode", keys: "⌘⎋")
    }

    // MARK: - Color Palette

    private static let paletteColors: [Color] = [
        // Neutrals
        .white,
        Color(hex: "#9CA3AF") ?? .gray,
        // Brand gradient range
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink,
        Color(hex: "#FFD166") ?? .yellow,
        // Cool & vibrant
        Color(hex: "#4FACFE") ?? .blue,
        Color(hex: "#A78BFA") ?? .purple,
        Color(hex: "#34D399") ?? .green,
        Color(hex: "#F472B6") ?? .pink,
        // Dark
        Color(hex: "#1E1B4B") ?? .indigo,
        Color(hex: "#111827") ?? .black,
    ]

    private var colorPaletteView: some View {
        VStack(spacing: 5) {
            // 4 cols × 3 rows of swatches
            let cols = 4
            let colors = Self.paletteColors
            let rows = stride(from: 0, to: colors.count, by: cols).map {
                Array(colors[$0 ..< min($0 + cols, colors.count)])
            }
            ForEach(rows.indices, id: \.self) { ri in
                HStack(spacing: 5) {
                    ForEach(rows[ri].indices, id: \.self) { ci in
                        colorSwatch(rows[ri][ci])
                    }
                }
            }

            // Custom picker as last row – small circle with gradient ring
            HStack(spacing: 5) {
                Spacer()
                ColorPicker("", selection: $drawingState.selectedColor)
                    .labelsHidden()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    .help("Custom color")
                Spacer()
            }
            .padding(.top, 1)
        }
        .padding(.vertical, 5)
    }

    private func colorSwatch(_ color: Color) -> some View {
        ColorSwatchButton(color: color, drawingState: drawingState)
    }

    // MARK: - Section label

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .tracking(1.2)
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
        RegularToolButton(tool: tool, drawingState: drawingState, pro: pro)
    }

    // MARK: - Shape tool button (outline or filled)

    @ViewBuilder
    private func shapeToolButton(_ tool: DrawingTool, filled: Bool) -> some View {
        ShapeToolButton(tool: tool, filled: filled, drawingState: drawingState)
    }

    // MARK: - Icon button

    private func iconButton(icon: String, tint: Color, help helpText: String,
                             keys: String? = nil,
                             action: @escaping () -> Void) -> some View {
        IconToolButton(icon: icon, tint: tint, helpText: helpText, keys: keys, action: action)
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

    // MARK: - Divider

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.8)
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
                .foregroundColor(.white.opacity(hoverExport ? 1.0 : 0.7))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(hoverExport ? 0.10 : 0.0))
                )
                .scaleEffect(hoverExport ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: hoverExport)
        }
        .menuStyle(.borderlessButton)
        .onHover { hoverExport = $0 }
        .toolTooltip("Export canvas")
    }
}

// MARK: - Tool tooltip (custom hover bubble)
//
// The toolbar panel is kept tight around the pill (see OverlayWindowManager),
// so an in-view SwiftUI tooltip would be clipped. Instead a tiny non-activating
// NSPanel floats next to the hovered button, above the toolbar's window level.

final class ToolTooltipController {
    static let shared = ToolTooltipController()
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?

    func schedule(title: String, keys: String?, isPro: Bool, anchor view: NSView) {
        pending?.cancel()
        // Chain instantly when moving between buttons while a tooltip is up.
        let delay = (panel?.isVisible == true) ? 0.05 : 0.3
        let item = DispatchWorkItem { [weak self, weak view] in
            guard let self, let view, view.window != nil else { return }
            self.show(title: title, keys: keys, isPro: isPro, anchor: view)
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func hide() {
        pending?.cancel()
        pending = nil
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in panel?.orderOut(nil) })
    }

    private func show(title: String, keys: String?, isPro: Bool, anchor view: NSView) {
        guard let win = view.window else { return }

        let hosting = NSHostingView(rootView: TooltipBubble(title: title, keys: keys, isPro: isPro))
        let size = hosting.fittingSize
        hosting.setFrameSize(size)

        let p: NSPanel
        if let existing = panel {
            p = existing
        } else {
            p = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
            p.backgroundColor    = .clear
            p.isOpaque           = false
            p.hasShadow          = true
            p.ignoresMouseEvents = true
            p.level              = .init(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.hidesOnDeactivate  = false
            panel = p
        }
        p.contentView = hosting

        // Position to the right of the button; flip left near the screen edge.
        let anchorRect = win.convertToScreen(view.convert(view.bounds, to: nil))
        var origin = CGPoint(x: anchorRect.maxX + 10, y: anchorRect.midY - size.height / 2)
        if let vis = win.screen?.visibleFrame {
            if origin.x + size.width > vis.maxX {
                origin.x = anchorRect.minX - size.width - 10
            }
            origin.y = min(max(origin.y, vis.minY + 4), vis.maxY - size.height - 4)
        }
        p.setFrame(NSRect(origin: origin, size: size), display: true)
        p.alphaValue = 0
        p.orderFrontRegardless()
        p.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            p.animator().alphaValue = 1
        }
    }
}

private struct TooltipBubble: View {
    let title: String
    let keys: String?
    let isPro: Bool

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .fixedSize()

            if isPro {
                Text("PRO")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(brandGradient))
            } else if let keys, !keys.isEmpty {
                HStack(spacing: 3) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { _, ch in
                        keycap(String(ch))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.16).opacity(0.96))
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(0.04))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .scaleEffect(appeared ? 1 : 0.92, anchor: .leading)
        .onAppear {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { appeared = true }
        }
    }

    private func keycap(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .frame(minWidth: 18)
            .frame(height: 18)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)
                    )
            )
    }
}

// Captures the hosting NSView so the tooltip can be positioned in screen coords.
private final class TooltipAnchorBox { weak var view: NSView? }

private struct TooltipAnchor: NSViewRepresentable {
    let box: TooltipAnchorBox
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        box.view = v
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) { box.view = nsView }
}

private struct ToolTooltipModifier: ViewModifier {
    let title: String
    let keys: String?
    let isPro: Bool
    @State private var box = TooltipAnchorBox()

    func body(content: Content) -> some View {
        content
            .background(TooltipAnchor(box: box))
            .onHover { hovering in
                if hovering, let view = box.view {
                    ToolTooltipController.shared.schedule(title: title, keys: keys, isPro: isPro, anchor: view)
                } else {
                    ToolTooltipController.shared.hide()
                }
            }
            .simultaneousGesture(TapGesture().onEnded { ToolTooltipController.shared.hide() })
    }
}

extension View {
    func toolTooltip(_ title: String, keys: String? = nil, isPro: Bool = false) -> some View {
        modifier(ToolTooltipModifier(title: title, keys: keys, isPro: isPro))
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

// MARK: - RegularToolButton

private struct RegularToolButton: View {
    let tool: DrawingTool
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var pro: ProManager
    @ObservedObject private var bindings = ToolBindingsStore.shared

    @State private var isHovered = false

    private let gradient = LinearGradient(
        colors: [Color(hex: "#F4644D") ?? .orange, Color(hex: "#FF8C42") ?? .orange, Color(hex: "#E9458C") ?? .pink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        let locked   = pro.isLocked(tool)
        let selected = !locked && drawingState.selectedTool == tool && !tool.isShape

        Button {
            if locked {
                NotificationCenter.default.post(name: .showPaywall, object: tool)
            } else {
                drawingState.selectTool(tool)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundColor(locked
                                     ? .white.opacity(0.28)
                                     : selected ? .white : .white.opacity(isHovered ? 0.85 : 0.55))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected
                                  ? AnyShapeStyle(gradient)
                                  : AnyShapeStyle(Color.white.opacity(isHovered ? 0.12 : 0.0)))
                            .shadow(
                                color: selected ? (Color(hex: "#F4644D") ?? .orange).opacity(0.5) : .clear,
                                radius: 6, x: 0, y: 2
                            )
                    )
                    .scaleEffect(isHovered && !selected ? 1.06 : 1.0)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(2.5)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .toolTooltip(tool.displayName,
                     keys: locked ? nil : bindings.bindings[tool],
                     isPro: locked)
    }
}

// MARK: - ShapeToolButton

private struct ShapeToolButton: View {
    let tool: DrawingTool
    let filled: Bool
    @ObservedObject var drawingState: DrawingState

    @State private var isHovered = false

    private let gradient = LinearGradient(
        colors: [Color(hex: "#F4644D") ?? .orange, Color(hex: "#FF8C42") ?? .orange, Color(hex: "#E9458C") ?? .pink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        let selected = drawingState.selectedTool == tool && drawingState.isFilled == filled
        let icon = filled ? tool.systemImage + ".fill" : tool.systemImage

        Button {
            drawingState.selectTool(tool)
            drawingState.isFilled = filled
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .white.opacity(isHovered ? 0.85 : 0.55))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected
                              ? AnyShapeStyle(gradient)
                              : AnyShapeStyle(Color.white.opacity(isHovered ? 0.12 : 0.0)))
                        .shadow(
                            color: selected ? (Color(hex: "#F4644D") ?? .orange).opacity(0.5) : .clear,
                            radius: 6, x: 0, y: 2
                        )
                )
                .scaleEffect(isHovered && !selected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .toolTooltip(tool.displayName + (filled ? " (filled)" : " (outline)"))
    }
}

// MARK: - ColorSwatchButton

private struct ColorSwatchButton: View {
    let color: Color
    @ObservedObject var drawingState: DrawingState
    @State private var isHovered = false

    private let gradient = LinearGradient(
        colors: [Color(hex: "#F4644D") ?? .orange, Color(hex: "#FF8C42") ?? .orange, Color(hex: "#E9458C") ?? .pink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private func colorMatches(_ a: Color, _ b: Color) -> Bool {
        guard let ca = NSColor(a).usingColorSpace(.displayP3),
              let cb = NSColor(b).usingColorSpace(.displayP3) else { return false }
        return abs(ca.redComponent   - cb.redComponent)   < 0.025 &&
               abs(ca.greenComponent - cb.greenComponent) < 0.025 &&
               abs(ca.blueComponent  - cb.blueComponent)  < 0.025
    }

    var body: some View {
        let selected = colorMatches(color, drawingState.selectedColor)
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .strokeBorder(
                        selected
                            ? AnyShapeStyle(gradient)
                            : AnyShapeStyle(Color.white.opacity(
                                isHovered ? 0.6 : (color == .white ? 0.5 : 0.15)
                              )),
                        lineWidth: selected ? 2 : (isHovered ? 1.2 : 0.8)
                    )
            )
            .scaleEffect(selected ? 1.25 : (isHovered ? 1.15 : 1.0))
            .shadow(color: selected ? color.opacity(0.6) : (isHovered ? color.opacity(0.4) : .clear), radius: selected ? 4 : 6)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selected)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
            .onTapGesture { drawingState.selectedColor = color }
    }
}

// MARK: - IconToolButton

private struct IconToolButton: View {
    let icon: String
    let tint: Color
    let helpText: String
    var keys: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(isHovered ? 0.10 : 0.0))
                )
                .scaleEffect(isHovered ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .toolTooltip(helpText, keys: keys)
    }
}
