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

private let shapePaletteColors: [Color] = [
    .white,
    Color(hex: "#9CA3AF") ?? .gray,
    Color(hex: "#F4644D") ?? .orange,
    Color(hex: "#FF8C42") ?? .orange,
    Color(hex: "#E9458C") ?? .pink,
    Color(hex: "#FFD166") ?? .yellow,
    Color(hex: "#4FACFE") ?? .blue,
    Color(hex: "#A78BFA") ?? .purple,
    Color(hex: "#34D399") ?? .green,
    Color(hex: "#F472B6") ?? .pink,
    Color(hex: "#1E1B4B") ?? .indigo,
    Color(hex: "#111827") ?? .black,
]

/// Lays content in an HStack when `horizontal`, otherwise a VStack — lets the
/// toolbar flip orientation without duplicating every section's layout.
private struct AdaptiveStack<Content: View>: View {
    let horizontal: Bool
    var spacing: CGFloat = 0
    var hAlign: VerticalAlignment = .center     // used when horizontal (HStack)
    var vAlign: HorizontalAlignment = .center   // used when vertical (VStack)
    @ViewBuilder var content: Content
    var body: some View {
        if horizontal {
            HStack(alignment: hAlign, spacing: spacing) { content }
        } else {
            VStack(alignment: vAlign, spacing: spacing) { content }
        }
    }
}

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

    private enum ChipSide { case none, shape, color }
    @State private var chipHoverSide     = ChipSide.none
    @State private var isHoveringModeButton = false
    @State private var hoverMinimize = false
    @State private var hoverExport   = false
    @State private var hoverOrient   = false
    @AppStorage("toolbarHorizontal") private var horizontal = false
    @StateObject private var exportManager = ExportManager()
    @StateObject private var shapesHover   = ShapesHoverManager()

    var body: some View {
        AdaptiveStack(horizontal: horizontal, spacing: 0, hAlign: .top) {
            dragHandle
                .shapesKeepAlive(shapesHover)
            // Mode button is vertical-only; the horizontal bar saves the space
            // (minimize in the handle still switches to interact mode).
            if !horizontal {
                modeButton.padding(.top, 6)
                    .shapesKeepAlive(shapesHover)
            }

            divider()

            section("DRAW") {
                toolGrid([
                    (.select,      false), (.cursor,      false),
                    (.pen,         false), (.highlighter, false),
                    (.marker,      false), (.blurBrush,   false),
                    (.eraser,      false), (.text,        false),
                    (.laserPointer,false), (.spotlight,   false),
                    (.dotPen,      false), (.cutMove,     false),
                    (.textCallout, false), (.stepBadge,   false),
                ])
            }
            .shapesKeepAlive(shapesHover)

            divider()

            section("LINES") {
                toolGrid([(.arrow, false), (.line, false)])
            }
            .shapesKeepAlive(shapesHover)

            divider()

            // SHAPES & COLOR — collapsed into hover dropdown
            shapesColorsSection

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
            .shapesKeepAlive(shapesHover)

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
            .shapesKeepAlive(shapesHover)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            ZStack {
                VisualEffectBackground()
                panelTint.opacity(0.28)
                // Full-coverage drag layer — sits behind all buttons so empty
                // gaps in the toolbar body also move the window on drag.
                WindowDragHandle()
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
            // Drag grip — three capsules; a vertical stack of horizontal bars
            // when the toolbar is vertical, and vice-versa.
            AdaptiveStack(horizontal: horizontal, spacing: 3.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: horizontal ? 2.5 : 22,
                               height: horizontal ? 22 : 2.5)
                }
            }
            .overlay(WindowDragHandle())

            // Orientation toggle (start) + minimize (end) — grip stays centered
            // between them so nothing overlaps in the narrow handle.
            AdaptiveStack(horizontal: !horizontal, spacing: 4) {
                Button { horizontal.toggle() } label: {
                    Image(systemName: horizontal ? "rectangle.portrait" : "rectangle")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(hoverOrient ? 0.75 : 0.35))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.white.opacity(hoverOrient ? 0.18 : 0.08)))
                        .scaleEffect(hoverOrient ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.14), value: hoverOrient)
                }
                .buttonStyle(.plain)
                .onHover { hoverOrient = $0 }
                .toolTooltip(horizontal ? "Vertical layout" : "Horizontal layout", keys: nil)

                Spacer(minLength: 0)

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
            .padding(horizontal ? .vertical : .horizontal, 3)
        }
        .frame(width: horizontal ? 28 : 72, height: horizontal ? 72 : 28)
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
            Group {
                if horizontal {
                    // Horizontal toolbar: small, narrow button with the word
                    // stacked letter-by-letter (only the first letter capital).
                    // Letter size shrinks with word length so every mode's
                    // button is the SAME fixed height (Draw = Interact).
                    let letters = Array(label)
                    let n = max(1, letters.count)
                    let letterFont = min(13, 48 / CGFloat(n))
                    VStack(spacing: n > 5 ? 0 : 1) {
                        Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                        ForEach(Array(letters.enumerated()), id: \.offset) { _, ch in
                            Text(String(ch)).font(.system(size: letterFont, weight: .bold))
                        }
                    }
                    .frame(width: 34, height: 76)
                } else {
                    // Vertical toolbar: original wide pill (untouched).
                    HStack(spacing: 6) {
                        Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                        Text(label).font(.system(size: 9, weight: .bold)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                }
            }
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

    // MARK: - Shapes & Colors chip

    // Vertical only — horizontal mode expands rightward (uses shapesExpandedWidth instead).
    // divider×2 (~9px each) + shapePairGrid (140px) + colorPaletteView (62px) = 220px
    private let shapesExpandedHeight: CGFloat = 220
    // Horizontal mode: divider×2 (~9px) + shapePairGrid (140px) + colorPaletteView (109px) = 267px
    private let shapesExpandedWidth:  CGFloat = 267

    private var shapesColorsSection: some View {
        let shapeTool: DrawingTool = drawingState.selectedTool.isShape ? drawingState.selectedTool : .rectangle
        let shapeSelected = drawingState.selectedTool.isShape
        let shapeIcon = (shapeSelected && drawingState.isFilled)
            ? shapeTool.systemImage + ".fill"
            : shapeTool.systemImage
        let expanded    = shapesHover.isHeightExpanded
        let accentColor = drawingState.selectedColor

        // Shared shape/color content for the expanded panel
        let shapeList: [(DrawingTool, DrawingTool)] = [
            (.rectangle, .rectangle), (.ellipse, .ellipse),
            (.triangle,  .triangle),  (.diamond, .diamond),
        ]
        let supportsColor = drawingState.selectedTool.supportsColor

        // ── Chip background layers (reused for both orientations) ────────
        // The gradient directions differ: horizontal chip glows left↔right,
        // vertical chip glows top↔bottom.
        func chipBg(horizontal isH: Bool) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(shapeSelected
                          ? AnyShapeStyle(brandGradient.opacity(0.18))
                          : AnyShapeStyle(Color.white.opacity(expanded ? 0.10 : 0.07)))
                // Permanent bloom toward the color-swatch side
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [.clear, accentColor.opacity(0.14)],
                        startPoint: isH ? UnitPoint(x: 0.4, y: 0.5) : UnitPoint(x: 0.5, y: 0.4),
                        endPoint:   isH ? .trailing                  : .bottom
                    ))
                // Shape-side hover glow
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        startPoint: isH ? .leading : .top,
                        endPoint:   isH ? .trailing : .bottom
                    ))
                    .opacity(chipHoverSide == .shape ? 1 : 0)
                    .animation(.easeOut(duration: 0.14), value: chipHoverSide == .shape)
                // Color-side hover glow
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [.clear, accentColor.opacity(0.28)],
                        startPoint: isH ? UnitPoint(x: 0.3, y: 0.5) : UnitPoint(x: 0.5, y: 0.4),
                        endPoint:   isH ? .trailing                  : .bottom
                    ))
                    .opacity(chipHoverSide == .color ? 1 : 0)
                    .animation(.easeOut(duration: 0.14), value: chipHoverSide == .color)
                // Gradient border
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(expanded ? 0.30 : 0.18),
                                accentColor.opacity(0.30)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .animation(.easeInOut(duration: 0.09), value: expanded)
            .animation(.easeInOut(duration: 0.22), value: accentColor)
        }

        return Group {
            if horizontal {
                // ── HORIZONTAL TOOLBAR: narrow vertical strip + rightward expansion ──
                HStack(spacing: 0) {

                    // Vertical trigger: shape icon on top, color dot on bottom
                    VStack(spacing: 0) {
                        Image(systemName: shapeIcon)
                            .font(.system(size: 14, weight: shapeSelected ? .semibold : .regular))
                            .foregroundStyle(shapeSelected
                                             ? AnyShapeStyle(brandGradient)
                                             : AnyShapeStyle(Color.white.opacity(0.5)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onHover { h in chipHoverSide = h ? .shape : (chipHoverSide == .shape ? .none : chipHoverSide) }

                        Circle()
                            .fill(accentColor)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.0))
                            .shadow(color: accentColor.opacity(0.9), radius: 4)
                            .shadow(color: accentColor.opacity(0.45), radius: 9)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onHover { h in chipHoverSide = h ? .color : (chipHoverSide == .color ? .none : chipHoverSide) }
                    }
                    .frame(width: 34)
                    .background(chipBg(horizontal: false))  // top↔bottom gradients
                    .onHover { hovering in
                        if hovering { shapesHover.enter() }
                        else        { shapesHover.scheduleExit() }
                    }

                    // Rightward expansion — slides in from the left
                    ShapesExpandedSection(isVisible: shapesHover.isVisible, isHorizontal: true) {
                        HStack(spacing: 0) {
                            divider()
                            shapePairGrid(shapeList)
                            divider()
                            colorPaletteView
                                .disabled(!supportsColor)
                                .opacity(supportsColor ? 1 : 0.25)
                        }
                    }
                    .frame(width: expanded ? shapesExpandedWidth : 0, alignment: .leading)
                    .clipped()
                    .onHover { hovering in
                        guard shapesHover.isVisible else { return }
                        if hovering { shapesHover.enter() }
                        else        { shapesHover.scheduleExit() }
                    }
                }

            } else {
                // ── VERTICAL TOOLBAR: horizontal chip + downward expansion ──
                VStack(spacing: 0) {

                    // Horizontal chip: shape icon left, color dot right
                    HStack(spacing: 0) {
                        Image(systemName: shapeIcon)
                            .font(.system(size: 15, weight: shapeSelected ? .semibold : .regular))
                            .foregroundStyle(shapeSelected
                                             ? AnyShapeStyle(brandGradient)
                                             : AnyShapeStyle(Color.white.opacity(0.5)))
                            .frame(maxWidth: .infinity)
                            .onHover { h in chipHoverSide = h ? .shape : (chipHoverSide == .shape ? .none : chipHoverSide) }

                        ZStack {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 17, height: 17)
                                .overlay(Circle().strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.0))
                                .shadow(color: accentColor.opacity(0.9), radius: 4)
                                .shadow(color: accentColor.opacity(0.45), radius: 10)
                        }
                        .frame(maxWidth: .infinity)
                        .onHover { h in chipHoverSide = h ? .color : (chipHoverSide == .color ? .none : chipHoverSide) }
                    }
                    .frame(height: 34)
                    .background(chipBg(horizontal: true))   // left↔right gradients
                    .onHover { hovering in
                        if hovering { shapesHover.enter() }
                        else        { shapesHover.scheduleExit() }
                    }

                    // Downward expansion
                    ShapesExpandedSection(isVisible: shapesHover.isVisible) {
                        VStack(spacing: 0) {
                            hRule
                            shapePairGrid(shapeList)
                            hRule
                            colorPaletteView
                                .disabled(!supportsColor)
                                .opacity(supportsColor ? 1 : 0.25)
                        }
                    }
                    .frame(height: expanded ? shapesExpandedHeight : 0, alignment: .top)
                    .clipped()
                    .onHover { hovering in
                        guard shapesHover.isVisible else { return }
                        if hovering { shapesHover.enter() }
                        else        { shapesHover.scheduleExit() }
                    }
                }
            }
        }
    }

    // MARK: - Color Palette

    private var colorPaletteView: some View {
        VStack(spacing: 5) {
            // 4×3 vertically; 6×2 horizontally so the section stays ~2 rows tall
            let cols = horizontal ? 6 : 4
            let colors = shapePaletteColors
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

    // MARK: - Section (label above its content; block flows in cross-axis)

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            if !horizontal { sectionLabel(title) }   // labels omitted in horizontal
            content()
        }
    }

    // MARK: - Tool Grid — 2 columns (vertical) / 2 rows (horizontal)

    @ViewBuilder
    private func toolGrid(_ tools: [(DrawingTool, Bool)]) -> some View {
        // Split into pairs, then lay the pairs along the main axis.
        let pairs = stride(from: 0, to: tools.count, by: 2).map {
            Array(tools[$0 ..< min($0 + 2, tools.count)])
        }
        AdaptiveStack(horizontal: horizontal, spacing: 4) {
            ForEach(pairs.indices, id: \.self) { pi in
                // Each pair fills the cross-axis (a column when vertical, a row when horizontal)
                AdaptiveStack(horizontal: !horizontal, spacing: 4) {
                    ForEach(pairs[pi].indices, id: \.self) { ci in
                        regularToolButton(pairs[pi][ci].0)
                    }
                    if pairs[pi].count == 1 { regularToolSpacer }
                }
            }
        }
    }

    private var regularToolSpacer: some View { Color.clear.frame(width: 32, height: 32) }

    // MARK: - Shape Pair Grid (outline + filled)

    @ViewBuilder
    private func shapePairGrid(_ pairs: [(DrawingTool, DrawingTool)]) -> some View {
        AdaptiveStack(horizontal: horizontal, spacing: 4) {
            ForEach(pairs.indices, id: \.self) { i in
                AdaptiveStack(horizontal: !horizontal, spacing: 4) {
                    shapeToolButton(pairs[i].0, filled: false)
                    shapeToolButton(pairs[i].1, filled: true)
                }
            }
        }
    }

    // MARK: - Regular tool button

    @ViewBuilder
    private func regularToolButton(_ tool: DrawingTool) -> some View {
        RegularToolButton(tool: tool, drawingState: drawingState, pro: ProManager.shared)
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
        // A 2-item group stays compact by running across the cross-axis.
        AdaptiveStack(horizontal: !horizontal, spacing: 4) {
            left()
            right()
        }
    }

    // MARK: - Dividers

    // Fixed horizontal rule — always a thin horizontal line regardless of toolbar orientation.
    // Used inside shapesColorsSection where the layout is always a VStack.
    private var hRule: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.8)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func divider() -> some View {
        if horizontal {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.8)
                .padding(.horizontal, 4)
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.8)
                .padding(.vertical, 4)
        }
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
        // Delay matches the HoverDebouncer window so a rapid exit+enter pair
        // (from updateTrackingAreas after panel.setFrame) cancels before the
        // fade-out starts, preventing tooltip flicker.
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak panel] in panel?.orderOut(nil) })
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025, execute: item)
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

// MARK: - Shapes keep-alive modifier
// Applied to every toolbar section above/below the chip. While the accordion
// is open, hovering any section resets the close timer — preventing the
// accordion from closing as the user moves between tools and the chip area.

private extension View {
    func shapesKeepAlive(_ manager: ShapesHoverManager) -> some View {
        onHover { hovering in
            guard manager.isHeightExpanded else { return }
            if hovering { manager.enter() } else { manager.scheduleExit() }
        }
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

// MARK: - HoverDebouncer
// Cancels rapid exit+enter pairs from NSTrackingArea reinstalls (fired by panel.setFrame).
// Stored as @State reference type so it persists across parent re-renders without publishing.

private final class HoverDebouncer {
    private var work: DispatchWorkItem?
    func update(_ hovered: Bool, delay: Double = 0.025, action: @escaping (Bool) -> Void) {
        work?.cancel()
        let w = DispatchWorkItem { action(hovered) }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: w)
    }
}

// MARK: - RegularToolButton

private struct RegularToolButton: View {
    let tool: DrawingTool
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var pro: ProManager
    @ObservedObject private var bindings = ToolBindingsStore.shared

    @State private var isHovered = false
    @State private var debouncer = HoverDebouncer()

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
                ToolIconView(tool: tool, size: 15)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundColor(locked
                                     ? .white.opacity(0.28)
                                     : selected ? .white : .white.opacity(isHovered ? 0.85 : 0.55))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected
                                  ? AnyShapeStyle(brandGradient)
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
        .onHover { [debouncer] hovered in debouncer.update(hovered) { isHovered = $0 } }
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
    @State private var debouncer = HoverDebouncer()

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
                              ? AnyShapeStyle(brandGradient)
                              : AnyShapeStyle(Color.white.opacity(isHovered ? 0.12 : 0.0)))
                        .shadow(
                            color: selected ? (Color(hex: "#F4644D") ?? .orange).opacity(0.5) : .clear,
                            radius: 6, x: 0, y: 2
                        )
                )
                .scaleEffect(isHovered && !selected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { [debouncer] hovered in debouncer.update(hovered) { isHovered = $0 } }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .toolTooltip(tool.displayName + (filled ? " (filled)" : " (outline)"))
    }
}

// MARK: - LaserToolIcon
//
// Custom replacement for the "laser.burst" SF Symbol, which reads as a
// sparkle/sun. This one matches the redesigned effect: a small laser dot
// with a soft bloom and a short trail fading in from the upper-left.
// Built from plain shapes so it inherits whatever foreground style the
// call site applies (flat grays and gradients alike), like an SF Symbol.

struct LaserToolIcon: View {
    /// Point size of the icon's square canvas. Roughly matches the visual
    /// size of an SF Symbol at the same font point size.
    var size: CGFloat = 15

    var body: some View {
        let u = size / 16   // designed on a 16×16 grid
        ZStack {
            // Movement trail: fades out toward the upper-left. The gradient
            // mask gives a smooth dissolve rather than a drawn line.
            Path { p in
                p.move(to: CGPoint(x: 2.9 * u, y: 2.9 * u))
                p.addLine(to: CGPoint(x: 7.1 * u, y: 7.1 * u))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.9 * u, lineCap: .round))
            .mask(LinearGradient(
                stops: [.init(color: .white.opacity(0.0),  location: 0.0),
                        .init(color: .white.opacity(0.85), location: 1.0)],
                startPoint: .topLeading, endPoint: .center))

            // Soft bloom — two faint halos blend into a glow, not rings.
            Circle()
                .frame(width: 9.6 * u, height: 9.6 * u)
                .position(x: 10.9 * u, y: 10.9 * u)
                .opacity(0.10)
            Circle()
                .frame(width: 7.0 * u, height: 7.0 * u)
                .position(x: 10.9 * u, y: 10.9 * u)
                .opacity(0.18)

            // The laser dot
            Circle()
                .frame(width: 4.9 * u, height: 4.9 * u)
                .position(x: 10.9 * u, y: 10.9 * u)
        }
        .frame(width: size, height: size)
    }
}

/// Drop-in for `Image(systemName: tool.systemImage)` — routes tools whose
/// icon SF Symbols can't express to custom-drawn views.
struct ToolIconView: View {
    let tool: DrawingTool
    var size: CGFloat = 15
    /// SF Symbol to show for non-custom tools instead of tool.systemImage
    /// (SizeBar picks context-specific symbols per tool).
    var systemImageOverride: String? = nil

    var body: some View {
        if tool == .laserPointer {
            LaserToolIcon(size: size)
        } else {
            Image(systemName: systemImageOverride ?? tool.systemImage)
        }
    }
}

// MARK: - ColorSwatchButton

private struct ColorSwatchButton: View {
    let color: Color
    @ObservedObject var drawingState: DrawingState
    @State private var isHovered = false
    @State private var debouncer = HoverDebouncer()

    var body: some View {
        let selected = color == drawingState.selectedColor
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .strokeBorder(
                        selected
                            ? AnyShapeStyle(brandGradient)
                            : AnyShapeStyle(Color.white.opacity(
                                isHovered ? 0.6 : (color == .white ? 0.5 : 0.15)
                              )),
                        lineWidth: selected ? 2 : (isHovered ? 1.2 : 0.8)
                    )
            )
            .scaleEffect(selected ? 1.25 : (isHovered ? 1.15 : 1.0))
            .shadow(color: selected ? color.opacity(0.6) : (isHovered ? color.opacity(0.4) : .clear),
                    radius: selected ? 4 : 6)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selected)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { [debouncer] hovered in debouncer.update(hovered) { isHovered = $0 } }
            .onTapGesture { drawingState.selectedColor = color }
    }
}

// MARK: - Shapes hover manager
// Two separate booleans so the toolbar only re-renders TWICE total per expand/collapse
// (once for height, once for the animation trigger), never during the animation itself.

private final class ShapesHoverManager: ObservableObject {
    @Published var isHeightExpanded = false   // controls .frame(height:) instantly
    @Published var isVisible        = false   // animation trigger passed to ShapesExpandedSection

    // Both work items must be tracked so enter() can cancel either at any time.
    // hideWork  = the outer 220ms delay before starting the fade
    // collapseWork = the inner 220ms delay before collapsing height (fires after fade)
    private var hideWork:     DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?

    func enter() {
        // Cancel the entire pending close sequence — both the fade-trigger AND
        // the height-collapse step, whichever may still be pending.
        hideWork?.cancel();     hideWork     = nil
        collapseWork?.cancel(); collapseWork = nil

        // Guard on isVisible, not isHeightExpanded: if the accordion is in the
        // fade-out window (isVisible=false but isHeightExpanded still=true) and
        // the cursor comes back, we must re-show content (set isVisible=true).
        // The old guard on isHeightExpanded would return early here, leaving the
        // accordion stuck — height expanded, content invisible, no close timer.
        guard !isVisible else { return }

        isHeightExpanded = true
        isVisible = true
    }

    func scheduleExit() {
        hideWork?.cancel();     hideWork     = nil
        collapseWork?.cancel(); collapseWork = nil

        // Create the inner item first so it can be stored AND passed into the outer closure.
        let inner = DispatchWorkItem { [weak self] in
            self?.isHeightExpanded = false
        }
        collapseWork = inner

        let outer = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: inner)
        }
        hideWork = outer
        // 80ms exit debounce: fast enough to feel game-like, long enough to absorb
        // any spurious tracking-area events from the window edge.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: outer)
    }
}

// MARK: - Shapes expanded section (isolated re-render scope)
// @State opacity lives here — changes to it never touch FloatingToolbar.
// Result: textCallout, stepBadge, and every other toolbar button are completely
// unaffected during the reveal/hide animation.
// Note: no blur — blur(radius:) distorts the small color swatches and smears
// scale animations from freshly-installed tracking areas, causing a flicker.

private struct ShapesExpandedSection<Content: View>: View {
    let isVisible: Bool
    var isHorizontal: Bool = false   // true → slide left/right instead of up/down
    @ViewBuilder var content: () -> Content

    @State private var opacity: Double  = 0
    @State private var slideOff: CGFloat = -12

    var body: some View {
        content()
            .opacity(opacity)
            .offset(x: isHorizontal ? slideOff : 0,
                    y: isHorizontal ? 0 : slideOff)
            .task(id: isVisible) {
                if isVisible {
                    opacity  = 0
                    slideOff = -12
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.76)) {
                        opacity  = 1
                        slideOff = 0
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.07)) {
                        opacity  = 0
                        slideOff = -8
                    }
                }
            }
    }
}

// MARK: - IconToolButton

private struct IconToolButton: View {
    let icon: String
    let tint: Color
    let helpText: String
    var keys: String? = nil
    let action: () -> Void

    @State private var isHovered  = false
    @State private var debouncer  = HoverDebouncer()

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
        .onHover { [debouncer] hovered in debouncer.update(hovered) { isHovered = $0 } }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .toolTooltip(helpText, keys: keys)
    }
}
