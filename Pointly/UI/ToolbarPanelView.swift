import SwiftUI
import AppKit

/// Stacks the toolbar and its size bar: side-by-side for a vertical toolbar,
/// top-and-bottom for a horizontal one.
private struct OrientationStack<Content: View>: View {
    let horizontal: Bool   // true = toolbar is horizontal → size bar goes below
    var spacing: CGFloat = 0
    @ViewBuilder var content: Content
    var body: some View {
        if horizontal {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(alignment: .top, spacing: spacing) { content }
        }
    }
}

// MARK: - ToolbarPanelView

struct ToolbarPanelView: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    var onSizeChange: ((CGSize) -> Void)?
    var onClose: (() -> Void)?

    @State private var toolbarSize: CGSize = CGSize(width: 72, height: 360)
    @AppStorage("toolbarHorizontal") private var horizontal = false
    /// User-adjustable UI scale (Settings → Appearance). Written by
    /// SettingsStore; @AppStorage keeps the live toolbar in sync.
    @AppStorage("toolbarScale") private var toolbarScale = 1.12
    @State private var unscaledSize: CGSize = .zero

    private var isInteract: Bool { interactionMode.currentMode == .interact }
    private var scale: CGFloat { CGFloat(min(1.4, max(0.8, toolbarScale))) }

    var body: some View {
        Group {
            if isInteract {
                MiniToolbarPill(
                    drawingState: drawingState,
                    interactionMode: interactionMode,
                    onClose: onClose ?? {}
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.82, anchor: .topLeading)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.82, anchor: .topLeading)
                        .combined(with: .opacity)
                ))
            } else {
                // Vertical toolbar: size bar to the right. Horizontal toolbar:
                // size bar below, matching the toolbar's cross-axis extent.
                OrientationStack(horizontal: horizontal, spacing: 8) {
                    FloatingToolbar(drawingState: drawingState, interactionMode: interactionMode)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear    { toolbarSize = geo.size }
                                    .onChange(of: geo.size) { _, newSize in toolbarSize = newSize }
                            }
                        )

                    SizeBar(drawingState: drawingState, horizontal: horizontal)
                        .frame(width: horizontal ? toolbarSize.width : nil,
                               height: horizontal ? nil : toolbarSize.height)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toolbarSize)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.82, anchor: .topLeading)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.82, anchor: .topLeading)
                        .combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.76), value: isInteract)
        .fixedSize()
        // Scale trick: scaleEffect is purely visual, so measure the natural
        // size first, then claim a frame of natural × scale — layout, hit
        // testing, and the panel-fitting callback all see the scaled size.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear    { unscaledSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in unscaledSize = newSize }
            }
        )
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width:  unscaledSize == .zero ? nil : unscaledSize.width  * scale,
               height: unscaledSize == .zero ? nil : unscaledSize.height * scale,
               alignment: .topLeading)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear    { onSizeChange?(geo.size) }
                    .onChange(of: geo.size) { _, newSize in onSizeChange?(newSize) }
            }
        )
    }
}

// MARK: - Mini Toolbar Pill

private let miniGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let miniTint = Color(red: 0.06, green: 0.06, blue: 0.14)

private struct MiniVisualEffect: NSViewRepresentable {
    var cornerRadius: CGFloat = 20
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

struct MiniToolbarPill: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    var onClose: () -> Void

    @State private var isHoveringTool = false
    @State private var isHoveringMode = false
    @State private var isHoveringClose = false

    var body: some View {
        HStack(spacing: 0) {

            // Drag handle
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 14, height: 2)
                }
            }
            .padding(.horizontal, 10)
            .overlay(MiniDragHandle())

            // Thin separator
            separator

            // Tool icon — tap to expand back to full toolbar
            ToolIconView(tool: drawingState.selectedTool, size: 14)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(miniGradient)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringTool ? Color.white.opacity(0.1) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { isHoveringTool = $0 }
                .onTapGesture { interactionMode.switchTo(mode: .draw) }
                .animation(.easeInOut(duration: 0.15), value: isHoveringTool)
                .help("Expand toolbar")

            separator

            // Mode toggle button
            Button { interactionMode.toggleMode() } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(interactionMode.currentMode == .draw
                              ? AnyShapeStyle(miniGradient)
                              : AnyShapeStyle(Color.white.opacity(0.35)))
                        .frame(width: 6, height: 6)
                    Text(interactionMode.currentMode.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(isHoveringMode ? 1 : 0.75))
                        .tracking(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringMode ? Color.white.opacity(0.1) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringMode = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHoveringMode)

            separator

            // Close button
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(isHoveringClose ? 0.9 : 0.4))
                    .frame(width: 32, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringClose
                                  ? (Color(hex: "#F4644D") ?? .red).opacity(0.25)
                                  : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringClose = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHoveringClose)
            .padding(.trailing, 4)
        }
        .frame(height: 40)
        .background(
            ZStack {
                MiniVisualEffect()
                miniTint.opacity(0.28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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
            miniGradient
                .frame(height: 1)
                .clipShape(Capsule())
                .shadow(color: (Color(hex: "#E9458C") ?? .pink).opacity(0.7), radius: 6, x: 0, y: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 2)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.8)
            .padding(.vertical, 8)
    }
}

// MARK: - Mini drag handle (NSView-backed, same as toolbar)

private struct MiniDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ v: DragView, context: Context) {}

    class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
