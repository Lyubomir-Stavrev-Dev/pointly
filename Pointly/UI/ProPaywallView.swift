import SwiftUI
import AppKit

// MARK: - Brand (local copy)

private let paywallGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink,
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let paywallTint = Color(red: 0.06, green: 0.06, blue: 0.14)

// MARK: - Glass

private struct PaywallGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: - DrawingTool Pro metadata

extension DrawingTool {
    var proTitle: String {
        switch self {
        case .blurBrush:    return "Blur Brush"
        case .laserPointer: return "Laser Pointer"
        case .spotlight:    return "Spotlight"
        case .dotPen:       return "Dot Pen"
        case .screenBlur:   return "Screen Blur"
        default:            return displayName
        }
    }
    var proTagline: String {
        switch self {
        case .blurBrush:    return "Protect sensitive info by painting a smooth blur over any part of your screen."
        case .laserPointer: return "Guide your audience with a glowing laser dot that fades naturally as you move."
        case .spotlight:    return "Dim everything and spotlight exactly what matters — perfect for live demos."
        case .dotPen:       return "Draw precise dotted lines and math-style diagrams with perfect spacing."
        case .screenBlur:   return "Brush over any area to instantly blur the screen content beneath the overlay."
        default:            return ""
        }
    }
}

// MARK: - Main view

struct ProPaywallView: View {
    let tool: DrawingTool
    @ObservedObject var proManager: ProManager
    var onDismiss: () -> Void

    private let proFeatures = [
        ("camera.filters",   "Blur Brush — protect sensitive content"),
        ("laser.burst",      "Laser Pointer — guide with precision"),
        ("rays",             "Spotlight — focus your audience"),
        ("circle.grid.3x3",  "Dot Pen — math-style dotted drawing"),
        ("smoke",            "Screen Blur — blur content behind overlay"),
    ]

    var body: some View {
        ZStack {
            ZStack {
                PaywallGlass()
                paywallTint.opacity(0.65)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.top, 18)
                .padding(.trailing, 20)

                // Feature animation
                ZStack {
                    switch tool {
                    case .blurBrush:    BlurBrushPreview()
                    case .laserPointer: LaserPointerPreview()
                    case .spotlight:    SpotlightPreview()
                    case .dotPen:       DotPenPreview()
                    case .screenBlur:   ScreenBlurPreview()
                    default:            defaultPreview
                    }
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 28)
                .padding(.top, 4)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.8)
                    .padding(.top, 20)

                VStack(spacing: 20) {
                    // Lock + title + tagline
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(paywallGradient)
                                .frame(width: 38, height: 38)
                                .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.5), radius: 10, x: 0, y: 4)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text(tool.proTitle + " is Pro")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(tool.proTagline)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.48))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)

                    // Feature list
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(proFeatures, id: \.0) { icon, label in
                            HStack(spacing: 10) {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(paywallGradient)
                                    .frame(width: 18)
                                Text(label)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                        }
                    }
                    .padding(.horizontal, 36)

                    // CTA
                    VStack(spacing: 10) {
                        Button {
                            Task { await proManager.purchase() }
                        } label: {
                            ZStack {
                                if proManager.purchaseInProgress {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    VStack(spacing: 2) {
                                        Text("Unlock Pointly Pro")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("$9.99 · One-Time · Lifetime Access")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.65))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(paywallGradient)
                                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.48),
                                            radius: 14, x: 0, y: 6)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(proManager.purchaseInProgress)

                        if let err = proManager.errorMessage {
                            Text(err)
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 20) {
                            Button("Restore Purchase") {
                                Task { await proManager.restorePurchases() }
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .buttonStyle(.plain)

                            Text("·")
                                .foregroundColor(.white.opacity(0.15))

                            Button("Maybe Later") { onDismiss() }
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                }

                Spacer(minLength: 20)
            }
        }
        .frame(width: 400, height: 560)
        .preferredColorScheme(.dark)
        // Auto-dismiss when purchase completes
        .onChange(of: proManager.isPro) { isPro in
            if isPro { onDismiss() }
        }
    }

    private var defaultPreview: some View {
        Image(systemName: tool.systemImage)
            .font(.system(size: 48))
            .foregroundStyle(paywallGradient)
    }
}

// MARK: - Blur Brush Preview
// The blur brush paints a soft, feathered stroke of colour — like an airbrush.
// Shows: brush cursor draws strokes on a canvas; each stroke has blurry/soft edges.

private struct BlurBrushPreview: View {

    private struct Stroke {
        var points: [CGPoint]
        var color: Color
        var width: CGFloat
    }

    @State private var finishedStrokes: [Stroke] = []
    @State private var livePoints:      [CGPoint] = []
    @State private var cursorPos = CGPoint(x: 20, y: 95)

    // Three overlapping brush strokes
    private let paths: [([CGPoint], Color, CGFloat)] = [
        (
            stride(from: 30.0, through: 330.0, by: 14).map { x in
                CGPoint(x: x, y: 80 + sin(x / 30) * 12)
            },
            Color(hex: "#F4644D") ?? .orange, 28
        ),
        (
            stride(from: 330.0, through: 30.0, by: -14).map { x in
                CGPoint(x: x, y: 115 + sin(x / 28) * 10)
            },
            Color(hex: "#E9458C") ?? .pink, 22
        ),
        (
            stride(from: 60.0, through: 300.0, by: 14).map { x in
                CGPoint(x: x, y: 148 + sin(x / 32) * 8)
            },
            Color(hex: "#FF8C42") ?? .orange, 18
        ),
    ]

    var body: some View {
        ZStack {
            // Dark canvas
            Color(red: 0.06, green: 0.06, blue: 0.12)

            // Finished strokes
            ForEach(finishedStrokes.indices, id: \.self) { i in
                softStroke(points: finishedStrokes[i].points,
                           color: finishedStrokes[i].color,
                           width: finishedStrokes[i].width)
            }

            // Live stroke being drawn
            if livePoints.count > 1 {
                let (_, color, width) = paths[finishedStrokes.count % paths.count]
                softStroke(points: livePoints, color: color, width: width)
            }

            // Brush cursor — soft circle outline like a real brush tip
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 30, height: 30)
            }
            .position(cursorPos)
        }
        .task {
            while true {
                finishedStrokes = []
                livePoints      = []

                for (pts, color, width) in paths {
                    cursorPos  = pts[0]
                    livePoints = []
                    try? await Task.sleep(nanoseconds: 200_000_000)

                    for pt in pts {
                        withAnimation(.linear(duration: 0.05)) { cursorPos = pt }
                        livePoints.append(pt)
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    finishedStrokes.append(Stroke(points: livePoints, color: color, width: width))
                    livePoints = []
                    try? await Task.sleep(nanoseconds: 180_000_000)
                }

                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.easeOut(duration: 0.5)) { finishedStrokes = [] }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
    }

    @ViewBuilder
    private func softStroke(points: [CGPoint], color: Color, width: CGFloat) -> some View {
        let path = Path { p in
            p.move(to: points[0])
            for pt in points.dropFirst() { p.addLine(to: pt) }
        }
        ZStack {
            // Soft outer halo — gives the feathered airbrush look
            path
                .stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: width + 14, lineCap: .round, lineJoin: .round))
                .blur(radius: 9)
            // Core stroke
            path
                .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                .blur(radius: 3)
        }
    }
}

// MARK: - Laser Pointer Preview
// The laser draws a glowing stroke along your cursor path, then it fades away automatically.
// Shows: cursor moves → neon glowing stroke appears → stroke fades out.

private struct LaserPointerPreview: View {
    @State private var drawProgress: CGFloat = 0
    @State private var globalOpacity: Double = 1.0
    @State private var cursorPos = CGPoint(x: 30, y: 95)

    private let laserPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30, y: 120))
        p.addCurve(
            to:       CGPoint(x: 195, y: 70),
            control1: CGPoint(x: 90,  y: 60),
            control2: CGPoint(x: 150, y: 55)
        )
        p.addCurve(
            to:       CGPoint(x: 360, y: 115),
            control1: CGPoint(x: 245, y: 85),
            control2: CGPoint(x: 310, y: 145)
        )
        return p
    }()

    // Sample cursor position along the path at given progress t ∈ [0,1]
    private func point(at t: CGFloat) -> CGPoint {
        // Approximate via parametric Bezier eval
        let p0 = CGPoint(x: 30,  y: 120)
        let p1 = CGPoint(x: 90,  y: 60)
        let p2 = CGPoint(x: 150, y: 55)
        let p3 = CGPoint(x: 195, y: 70)
        let p4 = CGPoint(x: 245, y: 85)
        let p5 = CGPoint(x: 310, y: 145)
        let p6 = CGPoint(x: 360, y: 115)

        if t <= 0.5 {
            let u = t * 2
            return cubicBezier(p0, p1, p2, p3, t: u)
        } else {
            let u = (t - 0.5) * 2
            return cubicBezier(p3, p4, p5, p6, t: u)
        }
    }

    private func cubicBezier(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt*mt*mt*a.x + 3*mt*mt*t*b.x + 3*mt*t*t*c.x + t*t*t*d.x,
            y: mt*mt*mt*a.y + 3*mt*mt*t*b.y + 3*mt*t*t*c.y + t*t*t*d.y
        )
    }

    var body: some View {
        ZStack {
            Color.white.opacity(0.03)

            // Fake slide content
            VStack(alignment: .leading, spacing: 9) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.12)).frame(width: 200, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).frame(width: 170, height: 7)
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).frame(width: 190, height: 7)
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).frame(width: 140, height: 7)
            }
            .offset(x: -60, y: -15)

            // Wide outer glow
            laserPath
                .trim(from: 0, to: drawProgress)
                .stroke(
                    (Color(hex: "#F4644D") ?? .orange).opacity(0.35),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 10)
                .opacity(globalOpacity)

            // Mid glow
            laserPath
                .trim(from: 0, to: drawProgress)
                .stroke(
                    (Color(hex: "#FF8C42") ?? .orange).opacity(0.65),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 3)
                .opacity(globalOpacity)

            // Bright core
            laserPath
                .trim(from: 0, to: drawProgress)
                .stroke(
                    Color.white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .opacity(globalOpacity)

            // Cursor dot at stroke tip
            ZStack {
                Circle()
                    .fill((Color(hex: "#F4644D") ?? .orange).opacity(0.4))
                    .frame(width: 18, height: 18)
                    .blur(radius: 5)
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
            }
            .position(cursorPos)
            .opacity(drawProgress < 1 ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: drawProgress)
        }
        .task {
            while true {
                drawProgress  = 0
                globalOpacity = 1.0
                cursorPos     = point(at: 0)
                try? await Task.sleep(nanoseconds: 300_000_000)

                // Draw the stroke, moving cursor along path
                let steps = 40
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    withAnimation(.linear(duration: 0.04)) {
                        drawProgress = t
                        cursorPos    = point(at: t)
                    }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }

                // Hold briefly, then fade — matches the real 3-second auto-fade
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(.easeIn(duration: 1.0)) { globalOpacity = 0 }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
            }
        }
    }
}

// MARK: - Dot Pen Preview
// Glowing dots trace a Lissajous figure-8 — the same animation that was
// saved from the original laser concept. Full faint path visible as guide dots.

private struct DotPenPreview: View {
    @State private var startDate: Date = .now

    private let trailLength = 18

    private func lissajousPoint(t: CGFloat, in size: CGSize) -> CGPoint {
        let cx = size.width  / 2
        let cy = size.height / 2
        let rx = size.width  * 0.37
        let ry = size.height * 0.37
        return CGPoint(
            x: cx + rx * sin(2 * t * .pi * 2),
            y: cy + ry * sin(t * .pi * 2)
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { tl in
            GeometryReader { geo in
                let elapsed  = tl.date.timeIntervalSince(startDate)
                let progress = CGFloat(elapsed.truncatingRemainder(dividingBy: 4.0) / 4.0)

                ZStack {
                    Color(red: 0.06, green: 0.06, blue: 0.12)

                    Canvas { ctx, size in
                        // Faint guide dots showing the full figure-8 path
                        let guideCount = 80
                        for i in 0..<guideCount {
                            let t = CGFloat(i) / CGFloat(guideCount)
                            let pt = lissajousPoint(t: t, in: size)
                            let r: CGFloat = 1.3
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)),
                                with: .color(Color.white.opacity(0.14))
                            )
                        }

                        // Glowing animated trail
                        for i in 0..<trailLength {
                            let t = (progress - CGFloat(i) * 0.016 + 2.0)
                                .truncatingRemainder(dividingBy: 1.0)
                            let pt   = lissajousPoint(t: t, in: size)
                            let fade = pow(CGFloat(trailLength - i) / CGFloat(trailLength), 1.5)
                            let coreR = 3.8 * fade
                            let glowR = 10.0 * fade

                            ctx.fill(
                                Path(ellipseIn: CGRect(x: pt.x - glowR, y: pt.y - glowR,
                                                       width: glowR*2, height: glowR*2)),
                                with: .color((Color(hex: "#F4644D") ?? .orange).opacity(Double(fade) * 0.30))
                            )
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: pt.x - coreR, y: pt.y - coreR,
                                                       width: coreR*2, height: coreR*2)),
                                with: .color(Color.white.opacity(Double(fade) * 0.92))
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Screen Blur Preview
// Fake screen content (UI blocks) with a brush sweeping and leaving a
// frosted-glass blurred trail — represents blurring the screen behind the overlay.

private struct ScreenBlurPreview: View {

    @State private var blurProgress: [CGFloat] = [0, 0, 0]
    @State private var cursorPos = CGPoint(x: 50, y: 95)

    private let brushPaths: [[CGPoint]] = [
        stride(from: 40.0,  through: 320.0, by: 11).map { x in CGPoint(x: x, y: 60 + sin(x / 40) * 9) },
        stride(from: 310.0, through:  55.0, by: -11).map { x in CGPoint(x: x, y: 100 + sin(x / 35) * 10) },
        stride(from: 75.0,  through: 285.0, by: 11).map { x in CGPoint(x: x, y: 142 + sin(x / 38) * 7) },
    ]

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.18)

            // Fake screen UI content
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill((Color(hex: "#F4644D") ?? .orange).opacity(0.7))
                        .frame(width: 80, height: 22)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.09))
                        .frame(width: 110, height: 22)
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 185, height: 10)
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill((Color(hex: "#4FACFE") ?? .blue).opacity(0.45))
                        .frame(width: 58, height: 16)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 95, height: 16)
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 145, height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 10)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Frosted blur strokes applied so far
            ForEach(0..<brushPaths.count, id: \.self) { i in
                if blurProgress[i] > 0 {
                    let count = max(2, Int(blurProgress[i] * CGFloat(brushPaths[i].count)))
                    let pts   = Array(brushPaths[i].prefix(count))
                    FrostedStroke(points: pts)
                }
            }

            // Brush cursor
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.50), lineWidth: 1.2)
                    .frame(width: 26, height: 26)
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 26, height: 26)
            }
            .position(cursorPos)
        }
        .task {
            while true {
                blurProgress = [0, 0, 0]
                try? await Task.sleep(nanoseconds: 400_000_000)

                for i in 0..<brushPaths.count {
                    let pts = brushPaths[i]
                    withAnimation(.linear(duration: 0.05)) { cursorPos = pts[0] }
                    try? await Task.sleep(nanoseconds: 150_000_000)

                    for j in 1...pts.count {
                        let prog = CGFloat(j) / CGFloat(pts.count)
                        withAnimation(.linear(duration: 0.045)) {
                            cursorPos    = pts[min(j, pts.count - 1)]
                            blurProgress[i] = prog
                        }
                        try? await Task.sleep(nanoseconds: 45_000_000)
                    }
                    try? await Task.sleep(nanoseconds: 180_000_000)
                }

                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.easeOut(duration: 0.55)) { blurProgress = [0, 0, 0] }
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
        }
    }
}

private struct FrostedStroke: View {
    let points: [CGPoint]

    var body: some View {
        let path = Path { p in
            guard points.count > 1 else { return }
            p.move(to: points[0])
            for pt in points.dropFirst() { p.addLine(to: pt) }
        }
        ZStack {
            path
                .stroke(Color.white.opacity(0.10),
                        style: StrokeStyle(lineWidth: 36, lineCap: .round, lineJoin: .round))
                .blur(radius: 10)
            path
                .stroke(Color.white.opacity(0.16),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                .blur(radius: 5)
            path
                .stroke(Color.white.opacity(0.22),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                .blur(radius: 2)
            path
                .stroke(Color.white.opacity(0.28),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Spotlight Preview

private struct SpotlightPreview: View {
    @State private var spotPos = CGPoint(x: 200, y: 95)

    private let waypoints: [CGPoint] = [
        CGPoint(x: 130, y: 70),
        CGPoint(x: 270, y: 110),
        CGPoint(x: 190, y: 140),
        CGPoint(x: 110, y: 100),
    ]

    var body: some View {
        ZStack {
            // Fake content behind spotlight
            Color(red: 0.08, green: 0.08, blue: 0.16)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: [180, 140, 200, 120][i], height: 9)
                }
            }
            .offset(x: -60)

            // Vignette: dark everywhere, bright circle at spotPos
            GeometryReader { geo in
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear,                location: 0.0),
                        .init(color: .clear,                location: 0.28),
                        .init(color: .black.opacity(0.92),  location: 0.60),
                        .init(color: .black.opacity(0.97),  location: 1.0),
                    ]),
                    center: UnitPoint(
                        x: spotPos.x / geo.size.width,
                        y: spotPos.y / geo.size.height
                    ),
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.75
                )
            }

            // Soft glow ring at spotlight center
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                .blur(radius: 4)
                .frame(width: 110, height: 110)
                .position(spotPos)
        }
        .task {
            var i = 0
            while true {
                withAnimation(.easeInOut(duration: 1.3)) {
                    spotPos = waypoints[i % waypoints.count]
                }
                i += 1
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }
}
