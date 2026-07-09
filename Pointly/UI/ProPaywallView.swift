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
        case .cutMove:      return "Cut & Move"
        default:            return displayName
        }
    }
    var proTagline: String {
        switch self {
        case .blurBrush:    return "Protect sensitive info by painting a smooth blur over any part of your screen."
        case .laserPointer: return "Guide your audience with a glowing laser dot that fades naturally as you move."
        case .spotlight:    return "Dim everything and spotlight exactly what matters — perfect for live demos."
        case .dotPen:       return "Draw precise dotted lines and math-style diagrams with perfect spacing."
        case .cutMove:      return "Draw a rectangle to select any annotations and drag them to a new position."
        default:            return ""
        }
    }
}

// MARK: - Main view

struct ProPaywallView: View {
    let tool: DrawingTool?
    var isWhiteboardCanvas: Bool = false
    @ObservedObject var proManager: ProManager
    var onDismiss: () -> Void
    var initialPlan: ProPlan = .annual

    @State private var selectedPlan: ProPlan = .annual
    @State private var hoverCTA = false
    #if DIRECT_BUILD
    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var licenseKey = ""
    #endif

    private let proFeatures = [
        ("camera.filters",   "Blur Brush — protect sensitive content"),
        ("laser.burst",      "Laser Pointer — guide with precision"),
        ("rays",             "Spotlight — focus your audience"),
        ("circle.dotted",    "Dot Pen — math-style dotted drawing"),
        ("scissors",         "Cut & Move — rearrange annotations freely"),
        ("grid",             "Whiteboard Canvas — draw on a dark grid canvas"),
    ]

    var body: some View {
        ZStack {
            ZStack {
                PaywallGlass()
                paywallTint.opacity(0.65)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Feature animation
                ZStack {
                    if isWhiteboardCanvas {
                        WhiteboardCanvasPreview()
                    } else if let tool {
                        switch tool {
                        case .blurBrush:    BlurBrushPreview()
                        case .laserPointer: LaserPointerPreview()
                        case .spotlight:    SpotlightPreview()
                        case .dotPen:       DotPenPreview()
                        case .cutMove:      CutMovePreview()
                        default:            genericProPreview
                        }
                    } else {
                        genericProPreview
                    }
                }
                .frame(height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.8)
                    .padding(.top, 16)

                VStack(spacing: 12) {
                    // Header
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(paywallGradient)
                                .frame(width: 36, height: 36)
                                .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.5), radius: 10, x: 0, y: 4)
                            Image(systemName: (tool != nil || isWhiteboardCanvas) ? "lock.fill" : "crown.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(isWhiteboardCanvas ? "Whiteboard Canvas is Pro" : tool != nil ? "\(tool!.proTitle) is Pro" : "Unlock Pointly Pro")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if let tool {
                            Text(tool.proTagline)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 12)

                    // Feature list (compact)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(proFeatures, id: \.0) { icon, label in
                            HStack(spacing: 9) {
                                Image(systemName: icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(paywallGradient)
                                    .frame(width: 16)
                                Text(label)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.60))
                            }
                        }
                    }
                    .padding(.horizontal, 36)

                    // Plan selector
                    HStack(spacing: 10) {
                        ForEach(ProPlan.allCases, id: \.self) { plan in
                            planCard(plan)
                        }
                    }
                    .padding(.horizontal, 28)

                    // CTA
                    VStack(spacing: 8) {
                        Button {
                            #if DIRECT_BUILD
                            NSWorkspace.shared.open(URL(string: "https://trypointly.com/buy?plan=\(selectedPlan.rawValue)")!)
                            #else
                            Task { await proManager.purchase(plan: selectedPlan) }
                            #endif
                        } label: {
                            ZStack {
                                if proManager.purchaseInProgress {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    VStack(spacing: 2) {
                                        #if DIRECT_BUILD
                                        Text("Buy \(selectedPlan.displayName)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("\(selectedPlan.fallbackPrice) \(selectedPlan.period) · on trypointly.com — license key by email")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.65))
                                        #else
                                        Text("Get \(selectedPlan.displayName)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("\(proManager.product(for: selectedPlan)?.displayPrice ?? selectedPlan.fallbackPrice) · \(selectedPlan == .annual ? "Billed annually" : "Lifetime access")")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.65))
                                        #endif
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(paywallGradient)
                                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(hoverCTA ? 0.70 : 0.48),
                                            radius: hoverCTA ? 20 : 14, x: 0, y: 6)
                            )
                            .scaleEffect(hoverCTA ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.14), value: hoverCTA)
                        }
                        .buttonStyle(.plain)
                        .onHover { if !proManager.purchaseInProgress { hoverCTA = $0 } }
                        .disabled(proManager.purchaseInProgress)

                        // Fixed-height slot so an error appearing never pushes the
                        // required Terms/Privacy links out of the sheet.
                        #if DIRECT_BUILD
                        Text(licenseManager.errorMessage ?? proManager.errorMessage ?? " ")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(height: 12)
                        #else
                        Text(proManager.errorMessage ?? " ")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(height: 12)
                        #endif

                        #if DIRECT_BUILD
                        HStack(spacing: 8) {
                            TextField("License key", text: $licenseKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                                .frame(width: 175)
                                .onSubmit { Task { await licenseManager.activate(key: licenseKey) } }

                            Button {
                                Task { await licenseManager.activate(key: licenseKey) }
                            } label: {
                                if licenseManager.activationInProgress {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Activate").font(.system(size: 11, weight: .semibold))
                                }
                            }
                            .disabled(licenseManager.activationInProgress)

                            Button("Maybe Later") { onDismiss() }
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.28))
                                .buttonStyle(.plain)
                        }
                        #else
                        HStack(spacing: 20) {
                            Button("Restore Purchase") {
                                Task { await proManager.restorePurchases() }
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.28))
                            .buttonStyle(.plain)

                            Text("·").foregroundColor(.white.opacity(0.15))

                            Button("Maybe Later") { onDismiss() }
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.28))
                                .buttonStyle(.plain)
                        }
                        #endif

                        // Required by App Review (3.1.2) for auto-renewable subscriptions.
                        HStack(spacing: 8) {
                            Button("Terms of Use") {
                                NSWorkspace.shared.open(
                                    URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            }
                            Text("·").foregroundColor(.white.opacity(0.12))
                            Button("Privacy Policy") {
                                NSWorkspace.shared.open(
                                    URL(string: "https://trypointly.com/privacy")!)
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.38))
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 28)
                }

                Spacer(minLength: 12)
            }
        }
        .frame(width: 400, height: 644)
        .preferredColorScheme(.dark)
        .onAppear { selectedPlan = initialPlan }
        .onChange(of: proManager.isPro) { _, isPro in
            if isPro { onDismiss() }
        }
    }

    // MARK: - Plan card

    private func planCard(_ plan: ProPlan) -> some View {
        PaywallPlanCard(plan: plan, selectedPlan: $selectedPlan, proManager: proManager)
    }

}

// MARK: - WhiteboardCanvasPreview

private struct WhiteboardCanvasPreview: View {
    @State private var appeared = false
    @State private var phase: CGFloat = 0

    private let strokes: [(CGFloat, CGFloat, Double)] = [
        (140, 5, 0.0),
        (90,  4, 0.12),
        (190, 5, 0.24),
        (70,  3, 0.36),
        (160, 4, 0.48),
    ]

    var body: some View {
        ZStack {
            // Dark grid background (mirrors actual whiteboard)
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.05, green: 0.05, blue: 0.10)))
                var lines = Path()
                let step: CGFloat = 26
                var x: CGFloat = 0
                while x <= size.width  { lines.move(to: .init(x: x, y: 0)); lines.addLine(to: .init(x: x, y: size.height)); x += step }
                var y: CGFloat = 0
                while y <= size.height { lines.move(to: .init(x: 0, y: y)); lines.addLine(to: .init(x: size.width, y: y)); y += step }
                ctx.stroke(lines, with: .color(Color.white.opacity(0.07)), lineWidth: 0.5)
            }

            // Animated brand-coloured strokes appearing
            VStack(spacing: 10) {
                ForEach(Array(strokes.enumerated()), id: \.offset) { i, s in
                    let (width, height, delay) = s
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#F4644D") ?? .orange,
                                     Color(hex: "#E9458C") ?? .pink],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: appeared ? width : 0, height: height)
                        .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.45),
                                radius: 6, x: 0, y: 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78)
                            .delay(delay), value: appeared)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
        }
    }
}

private extension ProPaywallView {
    var genericProPreview: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.12)
            HStack(spacing: 20) {
                ForEach([("camera.filters", "#F4644D"), ("laser.burst", "#FF8C42"),
                         ("rays", "#E9458C"), ("circle.dotted", "#F4644D"), ("scissors", "#FF8C42")],
                        id: \.0) { icon, hex in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: hex) ?? .orange)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - PaywallPlanCard

private struct PaywallPlanCard: View {
    let plan: ProPlan
    @Binding var selectedPlan: ProPlan
    @ObservedObject var proManager: ProManager
    @State private var isHovered = false

    var body: some View {
        let selected = selectedPlan == plan
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedPlan = plan }
        } label: {
            VStack(spacing: 4) {
                Text(plan.badge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(selected ? .white : .white.opacity(isHovered ? 0.65 : 0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(selected ? AnyShapeStyle(paywallGradient) : AnyShapeStyle(Color.white.opacity(isHovered ? 0.14 : 0.08)))
                    )

                Text(plan.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(proManager.product(for: plan)?.displayPrice ?? plan.fallbackPrice)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(selected ? AnyShapeStyle(paywallGradient) : AnyShapeStyle(Color.white))
                    Text(plan.period)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(selected ? 0.07 : (isHovered ? 0.07 : 0.04)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selected
                                    ? AnyShapeStyle(paywallGradient)
                                    : AnyShapeStyle(Color.white.opacity(isHovered ? 0.22 : 0.1)),
                                lineWidth: selected ? 1.5 : 0.8
                            )
                    )
            )
            .scaleEffect(isHovered && !selected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.14), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
// Shows a math-diagram style drawing: a dotted circle being traced + dotted axes.
// Dots are clearly spaced, demonstrating the "math/diagram" dotted-line style.

private struct DotPenPreview: View {
    // Phase 0: draw axes; Phase 1: draw circle; Phase 2: hold; Phase 3: fade
    @State private var hAxisProg: CGFloat = 0
    @State private var vAxisProg: CGFloat = 0
    @State private var circleProg: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var cursorPos = CGPoint(x: 185, y: 95)

    private let cx: CGFloat = 185
    private let cy: CGFloat = 95
    private let r: CGFloat  = 52

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.12)

            // Subtle graph-paper dots
            Canvas { ctx, size in
                let sp: CGFloat = 20
                var x: CGFloat = fmod(size.width / 2, sp)
                while x < size.width {
                    var y: CGFloat = fmod(size.height / 2, sp)
                    while y < size.height {
                        let dot: CGFloat = 0.9
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x-dot, y: y-dot, width: dot*2, height: dot*2)),
                            with: .color(Color.white.opacity(0.08))
                        )
                        y += sp
                    }
                    x += sp
                }
            }

            // Horizontal axis dotted line
            if hAxisProg > 0 {
                let endX = cx - 120 + 240 * hAxisProg
                Path { p in
                    p.move(to: CGPoint(x: cx - 120, y: cy))
                    p.addLine(to: CGPoint(x: endX, y: cy))
                }
                .stroke(Color.white.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0, 8]))
                .opacity(opacity)
            }

            // Vertical axis dotted line
            if vAxisProg > 0 {
                let endY = cy - 70 + 140 * vAxisProg
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy - 70))
                    p.addLine(to: CGPoint(x: cx, y: endY))
                }
                .stroke(Color.white.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0, 8]))
                .opacity(opacity)
            }

            // Dotted circle
            Circle()
                .trim(from: 0, to: circleProg)
                .stroke(
                    AnyShapeStyle(paywallGradient),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [0, 9])
                )
                .frame(width: r * 2, height: r * 2)
                .rotationEffect(.degrees(-90))
                .position(x: cx, y: cy)
                .opacity(opacity)

            // Cursor dot
            ZStack {
                Circle()
                    .fill((Color(hex: "#F4644D") ?? .orange).opacity(0.35))
                    .frame(width: 14, height: 14)
                    .blur(radius: 4)
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
            }
            .position(cursorPos)
            .opacity(opacity)
        }
        .task {
            while true {
                hAxisProg = 0; vAxisProg = 0; circleProg = 0; opacity = 1
                cursorPos = CGPoint(x: cx - 120, y: cy)
                try? await Task.sleep(nanoseconds: 300_000_000)

                // Draw horizontal axis
                for i in 1...30 {
                    let p = CGFloat(i) / 30
                    withAnimation(.linear(duration: 0.04)) {
                        hAxisProg = p
                        cursorPos = CGPoint(x: cx - 120 + 240 * p, y: cy)
                    }
                    try? await Task.sleep(nanoseconds: 35_000_000)
                }
                try? await Task.sleep(nanoseconds: 120_000_000)

                // Draw vertical axis
                cursorPos = CGPoint(x: cx, y: cy - 70)
                for i in 1...20 {
                    let p = CGFloat(i) / 20
                    withAnimation(.linear(duration: 0.04)) {
                        vAxisProg = p
                        cursorPos = CGPoint(x: cx, y: cy - 70 + 140 * p)
                    }
                    try? await Task.sleep(nanoseconds: 35_000_000)
                }
                try? await Task.sleep(nanoseconds: 120_000_000)

                // Draw dotted circle
                cursorPos = CGPoint(x: cx, y: cy - r)
                for i in 1...50 {
                    let p = CGFloat(i) / 50
                    withAnimation(.linear(duration: 0.04)) {
                        circleProg = p
                        cursorPos = CGPoint(
                            x: cx + r * sin(p * .pi * 2),
                            y: cy - r * cos(p * .pi * 2)
                        )
                    }
                    try? await Task.sleep(nanoseconds: 35_000_000)
                }

                // Hold then fade
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeOut(duration: 0.5)) { opacity = 0 }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
    }
}

// MARK: - Cut & Move Preview
// Shows annotations on canvas, a dashed selection rectangle drawn around some,
// then those annotations sliding to a new position — demonstrates the tool's purpose.

private struct CutMovePreview: View {
    @State private var selectionRect: CGRect = .zero
    @State private var selectionOpacity: Double = 0
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    // Fixed annotation "strokes" on the canvas
    private let strokes: [(Color, [CGPoint])] = [
        (Color(hex: "#F4644D") ?? .orange, [
            CGPoint(x: 60, y: 60), CGPoint(x: 90, y: 90), CGPoint(x: 120, y: 70),
            CGPoint(x: 150, y: 100), CGPoint(x: 180, y: 75)
        ]),
        (Color(hex: "#4FACFE") ?? .blue, [
            CGPoint(x: 200, y: 130), CGPoint(x: 240, y: 110), CGPoint(x: 280, y: 140)
        ]),
        (Color(hex: "#E9458C") ?? .pink, [
            CGPoint(x: 80, y: 140), CGPoint(x: 110, y: 160), CGPoint(x: 140, y: 145),
            CGPoint(x: 170, y: 165)
        ]),
        (Color(hex: "#34D399") ?? .green, [
            CGPoint(x: 220, y: 60), CGPoint(x: 260, y: 80), CGPoint(x: 300, y: 55)
        ]),
    ]

    // Strokes 0 and 2 are "inside" the selection box; 1 and 3 stay put
    private let selectedIndices: Set<Int> = [0, 2]
    private let selRect = CGRect(x: 48, y: 48, width: 148, height: 132)
    private let targetOffset = CGSize(width: 100, height: 20)

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.12)

            Canvas { ctx, _ in
                // Draw non-selected strokes (always in place)
                for (i, (color, pts)) in strokes.enumerated() {
                    guard !selectedIndices.contains(i), pts.count > 1 else { continue }
                    var path = Path()
                    path.move(to: pts[0])
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                    ctx.stroke(path, with: .color(color.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }

            // Selected strokes — move with the offset
            Canvas { ctx, _ in
                for (i, (color, pts)) in strokes.enumerated() {
                    guard selectedIndices.contains(i), pts.count > 1 else { continue }
                    var path = Path()
                    path.move(to: pts[0].offset(dx: offsetX, dy: offsetY))
                    for pt in pts.dropFirst() {
                        path.addLine(to: pt.offset(dx: offsetX, dy: offsetY))
                    }
                    ctx.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }

            // Dashed selection rectangle
            if selectionOpacity > 0 {
                Rectangle()
                    .stroke(
                        Color.white.opacity(0.75),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .frame(width: selRect.width, height: selRect.height)
                    .offset(x: selRect.midX - 185, y: selRect.midY - 95)
                    .offset(x: offsetX, y: offsetY)
                    .opacity(selectionOpacity)

                // Corner handles
                ForEach([
                    CGPoint(x: selRect.minX, y: selRect.minY),
                    CGPoint(x: selRect.maxX, y: selRect.minY),
                    CGPoint(x: selRect.minX, y: selRect.maxY),
                    CGPoint(x: selRect.maxX, y: selRect.maxY),
                ], id: \.x) { pt in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .offset(x: pt.x - 185 + offsetX, y: pt.y - 95 + offsetY)
                        .opacity(selectionOpacity)
                }
            }
        }
        .task {
            while true {
                // Reset
                selectionOpacity = 0; offsetX = 0; offsetY = 0
                try? await Task.sleep(nanoseconds: 400_000_000)

                // Draw selection rectangle
                withAnimation(.easeOut(duration: 0.5)) { selectionOpacity = 1 }
                try? await Task.sleep(nanoseconds: 700_000_000)

                // Drag selected elements to new position
                withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
                    offsetX = CGFloat(targetOffset.width)
                    offsetY = CGFloat(targetOffset.height)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                // Fade selection box, keep elements in new position
                withAnimation(.easeOut(duration: 0.3)) { selectionOpacity = 0 }
                try? await Task.sleep(nanoseconds: 800_000_000)

                // Snap back
                withAnimation(.easeInOut(duration: 0.4)) { offsetX = 0; offsetY = 0 }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}

private extension CGPoint {
    func offset(dx: CGFloat, dy: CGFloat) -> CGPoint { CGPoint(x: x + dx, y: y + dy) }
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
