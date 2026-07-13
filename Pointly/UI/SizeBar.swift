import SwiftUI

// MARK: - Brand gradient (local copy — same values as SettingsView)

private let barGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink
    ],
    startPoint: .bottom,
    endPoint: .top
)

private let sizeBarTint = Color(red: 0.06, green: 0.06, blue: 0.14)

private struct SizeBarVisualEffect: NSViewRepresentable {
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

// MARK: - SizeBar

/// Adaptive vertical size control that lives to the right of the toolbar pill.
/// Adapts its icon and label to reflect whatever size-related property
/// the currently-selected tool exposes.
struct SizeBar: View {
    @ObservedObject var drawingState: DrawingState
    var horizontal: Bool = false

    private struct Config: Equatable {
        let icon: String
        let label: String
    }

    private var config: Config? {
        guard drawingState.selectedTool.supportsThickness else { return nil }
        switch drawingState.selectedTool {
        case .spotlight:    return Config(icon: "rays",            label: "SIZE")
        case .eraser:       return Config(icon: "eraser",          label: "SIZE")
        case .blurBrush:    return Config(icon: "camera.filters",  label: "BLUR")
        case .laserPointer: return Config(icon: "laser.burst",     label: "GLOW")
        case .highlighter:  return Config(icon: "highlighter",     label: "FILL")
        case .marker:       return Config(icon: "paintbrush",      label: "SIZE")
        case .text:         return Config(icon: "textformat.size",  label: "FONT")
        case .pen:          return Config(icon: "pencil.tip",      label: "SIZE")
        default:            return Config(icon: "line.diagonal",   label: "SIZE")
        }
    }

    var body: some View {
        Group {
            if let cfg = config {
                content(cfg)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75),
                                value: drawingState.selectedTool)
                    .background(
                        ZStack {
                            SizeBarVisualEffect()
                            sizeBarTint.opacity(0.28)
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
                    .frame(width: horizontal ? nil : 38, height: horizontal ? 40 : nil)
            }
        }
    }

    @ViewBuilder
    private func content(_ cfg: Config) -> some View {
        if horizontal {
            HStack(spacing: 10) {
                Image(systemName: cfg.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(barGradient)
                    .id(cfg.icon)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                HorizontalSizeSlider(value: $drawingState.strokeThickness, range: 1...30)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                Text("\(Int(drawingState.strokeThickness))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(barGradient)
                    .frame(width: 20, alignment: .trailing)
                Text(cfg.label)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .id(cfg.label)
                    .transition(.opacity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 8) {
                Image(systemName: cfg.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(barGradient)
                    .frame(height: 16)
                    .id(cfg.icon)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                VerticalSizeSlider(value: $drawingState.strokeThickness, range: 1...30)
                    .frame(width: 12)
                    .frame(maxHeight: .infinity)
                Text("\(Int(drawingState.strokeThickness))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(barGradient)
                Text(cfg.label)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .id(cfg.label)
                    .transition(.opacity)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - HorizontalSizeSlider

struct HorizontalSizeSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    private var normalized: CGFloat {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let fillW = max(10, w * normalized)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: h / 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: w, height: h)
                RoundedRectangle(cornerRadius: h / 2)
                    .fill(barGradient)
                    .frame(width: fillW, height: h)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7), value: value)
                Capsule()
                    .fill(Color.white)
                    .frame(width: 5, height: h + 8)
                    .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                    .offset(x: fillW - 2.5)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7), value: value)
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle().size(CGSize(width: w, height: h + 16)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let n = max(0, min(1, drag.location.x / w))
                        let raw = range.lowerBound + n * (range.upperBound - range.lowerBound)
                        value = raw.rounded()
                    }
            )
        }
    }
}

// MARK: - VerticalSizeSlider

struct VerticalSizeSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    private var normalized: CGFloat {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let fillH = max(10, h * normalized)

            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: w / 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: w, height: h)

                // Gradient fill — rises from the bottom
                RoundedRectangle(cornerRadius: w / 2)
                    .fill(barGradient)
                    .frame(width: w, height: fillH)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7),
                                value: value)

                // Thumb: horizontal capsule that sits at the top of the fill
                Capsule()
                    .fill(Color.white)
                    .frame(width: w + 8, height: 5)
                    .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                    .offset(y: -(fillH - 2.5))
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7),
                                value: value)
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle().size(CGSize(width: w + 16, height: h)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let n = max(0, min(1, 1 - drag.location.y / h))
                        let raw = range.lowerBound + n * (range.upperBound - range.lowerBound)
                        value = raw.rounded()
                    }
            )
        }
    }
}
