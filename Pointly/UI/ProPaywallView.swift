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
        default:            return displayName
        }
    }
    var proTagline: String {
        switch self {
        case .blurBrush:    return "Protect sensitive info by painting a smooth blur over any part of your screen."
        case .laserPointer: return "Guide your audience with a glowing laser dot that fades naturally as you move."
        case .spotlight:    return "Dim everything and spotlight exactly what matters — perfect for live demos."
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

private struct BlurBrushPreview: View {
    @State private var brushX: CGFloat = -60
    @State private var revealedCount = 0

    private let rows = [
        ("person.fill", "John Smith"),
        ("creditcard.fill", "4242 4242 4242 4242"),
        ("lock.fill", "Password: hunter2"),
    ]

    var body: some View {
        ZStack {
            Color.white.opacity(0.03)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        Image(systemName: rows[i].0)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 16)

                        if i < revealedCount {
                            Text(String(repeating: "●", count: 14))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.15))
                                .blur(radius: 2)
                        } else {
                            Text(rows[i].1)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: revealedCount)
                }
            }
            .padding(.leading, 36)

            // Brush cursor
            VStack(spacing: 0) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(paywallGradient)
                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.7), radius: 10)

                // Trail behind brush
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [(Color(hex: "#F4644D") ?? .orange).opacity(0.25), .clear],
                            startPoint: .trailing, endPoint: .leading
                        )
                    )
                    .frame(width: max(0, brushX + 60), height: 3)
                    .offset(x: -(max(0, brushX + 60)) / 2)
            }
            .offset(x: brushX, y: 0)
        }
        .task {
            while true {
                brushX = -60
                revealedCount = 0
                try? await Task.sleep(nanoseconds: 600_000_000)

                withAnimation(.linear(duration: 1.4)) { brushX = 240 }
                try? await Task.sleep(nanoseconds: 460_000_000)
                revealedCount = 1
                try? await Task.sleep(nanoseconds: 460_000_000)
                revealedCount = 2
                try? await Task.sleep(nanoseconds: 460_000_000)
                revealedCount = 3
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }
}

// MARK: - Laser Pointer Preview

private struct LaserPointerPreview: View {
    @State private var dotPos = CGPoint(x: 200, y: 95)
    @State private var trail: [CGPoint] = []
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            // Fake slide background
            Color.white.opacity(0.03)

            // Fake slide content
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 180, height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 140, height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 160, height: 8)
            }
            .offset(x: -60)

            // Fading trail
            Canvas { ctx, _ in
                for (i, pt) in trail.enumerated() {
                    let alpha = Double(i) / Double(max(1, trail.count)) * 0.55
                    var p = Path()
                    p.addEllipse(in: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
                    ctx.fill(p, with: .color(Color.red.opacity(alpha)))
                }
            }

            // Dot
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.25))
                    .frame(width: 22, height: 22)
                    .blur(radius: 6)
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .shadow(color: .red, radius: 4)
            }
            .position(dotPos)
        }
        .task {
            while true {
                phase += 0.12
                let x = 200.0 + 90.0 * cos(phase)
                let y = 95.0  + 45.0 * sin(2 * phase)
                let newPt = CGPoint(x: x, y: y)
                withAnimation(.linear(duration: 0.05)) { dotPos = newPt }
                trail.append(newPt)
                if trail.count > 22 { trail.removeFirst() }
                try? await Task.sleep(nanoseconds: 55_000_000)
            }
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
