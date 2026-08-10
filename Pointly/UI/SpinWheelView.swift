import SwiftUI
import AppKit

// MARK: - Brand (local copy, mirrors ProPaywallView)

private let wheelGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink,
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let wheelTint = Color(red: 0.06, green: 0.06, blue: 0.14)

private struct WheelGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: - Segments

private struct WheelSegment {
    let label: String
    let isGift: Bool
}

// The gift segment is the only claimable outcome — the wheel always lands on
// it, so every new user "wins" the same 60% Pro+ offer (no unlucky users, and
// only one discounted product to maintain in App Store Connect / Stripe).
private let segments: [WheelSegment] = [
    WheelSegment(label: "10%", isGift: false),
    WheelSegment(label: "25%", isGift: false),
    WheelSegment(label: "5%",  isGift: false),
    WheelSegment(label: "",    isGift: true),   // 🎁 60% off Pro+
    WheelSegment(label: "40%", isGift: false),
    WheelSegment(label: "15%", isGift: false),
]
private let giftIndex = segments.firstIndex(where: \.isGift) ?? 0

// MARK: - SpinWheelView

struct SpinWheelView: View {
    @ObservedObject var proManager: ProManager
    var onDismiss: () -> Void

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var landed = false
    @State private var hoverCTA = false
    @State private var hoverWheel = false
    @State private var glowPulse = false
    @State private var hintBob = false
    @State private var handCursorPushed = false

    private let wheelSize: CGFloat = 316

    // Push/pop must stay balanced — an unmatched pop() clobbers whatever
    // cursor the rest of the app had set.
    private func setHandCursor(_ on: Bool) {
        guard on != handCursorPushed else { return }
        handCursorPushed = on
        if on { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }

    var body: some View {
        ZStack {
            ZStack {
                WheelGlass()
                wheelTint.opacity(0.65)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text(landed ? "You won the grand prize! 🎉" : "Wait — spin before you go")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.opacity)
                    Text(landed
                         ? "60% off Pro+ — lifetime access, every Pro tool, forever."
                         : "One spin, one welcome discount on Pro+. New users only.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 26)
                .animation(.easeInOut(duration: 0.3), value: landed)

                // Wheel
                ZStack {
                    // Glow behind the wheel — brightens on hover, pulses on win
                    Circle()
                        .fill(wheelGradient)
                        .frame(width: wheelSize - 16, height: wheelSize - 16)
                        .blur(radius: 46)
                        .opacity(landed ? (glowPulse ? 0.55 : 0.3) : (hoverWheel ? 0.3 : 0.14))
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                   value: glowPulse)
                        .animation(.easeInOut(duration: 0.2), value: hoverWheel)

                    wheelBody
                        .frame(width: wheelSize, height: wheelSize)
                        .rotationEffect(.degrees(rotation))

                    // Hub
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.05, green: 0.05, blue: 0.11))
                            .frame(width: 74, height: 74)
                            .overlay(Circle().strokeBorder(wheelGradient, lineWidth: 2))
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 3)
                        if landed {
                            Text("60%")
                                .font(.system(size: 21, weight: .heavy, design: .rounded))
                                .foregroundStyle(wheelGradient)
                        } else {
                            Text("SPIN")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .allowsHitTesting(false)

                    // Pointer
                    Triangle()
                        .fill(Color.white)
                        .frame(width: 28, height: 24)
                        .rotationEffect(.degrees(180))
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                        .offset(y: -wheelSize / 2)

                    // Bobbing "click me" hand, sits on the wheel until it spins
                    if !spinning && !landed {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
                            .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.8), radius: 12)
                            .rotationEffect(.degrees(-12))
                            .offset(x: 58, y: 78)
                            .offset(x: hintBob ? -12 : 0, y: hintBob ? -12 : 0)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                       value: hintBob)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .frame(height: wheelSize + 34)
                .padding(.top, 8)
                .contentShape(Circle())
                .scaleEffect(hoverWheel && !spinning && !landed ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.18), value: hoverWheel)
                .onHover { hovering in
                    hoverWheel = hovering
                    setHandCursor(hovering && !spinning && !landed)
                }
                .onTapGesture { spin() }

                // CTA area
                VStack(spacing: 9) {
                    if landed {
                        Button {
                            claim()
                        } label: {
                            ZStack {
                                if proManager.purchaseInProgress {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    VStack(spacing: 2) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "gift.fill")
                                                .font(.system(size: 13, weight: .bold))
                                            Text("Claim 60% off Pro+")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        priceLine
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(wheelGradient)
                                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(hoverCTA ? 0.70 : 0.48),
                                            radius: hoverCTA ? 20 : 14, x: 0, y: 6)
                            )
                            .scaleEffect(hoverCTA ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.14), value: hoverCTA)
                        }
                        .buttonStyle(.plain)
                        .onHover { if !proManager.purchaseInProgress { hoverCTA = $0 } }
                        .disabled(proManager.purchaseInProgress)

                        Text("One-time welcome offer — it won't be shown again.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.35))
                    } else {
                        Text(spinning ? "Good luck…" : "Click the wheel to spin")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(height: 50)
                    }

                    Text(proManager.errorMessage ?? " ")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(height: 12)

                    Button("no thanks") { onDismiss() }
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.15))
                        .buttonStyle(.plain)
                        .disabled(spinning)
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 16)
            }
        }
        .frame(width: 400, height: 620)
        .preferredColorScheme(.dark)
        .onAppear {
            proManager.clearError()
            proManager.markSpinOfferShown()
            hintBob = true
        }
        .onChange(of: proManager.isPro) { _, isPro in
            if isPro { onDismiss() }
        }
    }

    // MARK: - Price line under the claim CTA

    @ViewBuilder
    private var priceLine: some View {
        #if DIRECT_BUILD
        Text("€15.99 one-time (was €39.99) · on trypointly.com")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.65))
        #else
        // Real localized prices once StoreKit products load.
        let offer = proManager.spinOfferProduct?.displayPrice
        let full  = proManager.product(for: .lifetime)?.displayPrice
        HStack(spacing: 5) {
            if let full {
                Text(full).strikethrough()
                    .foregroundColor(.white.opacity(0.45))
            }
            Text("\(offer ?? "…") · Lifetime access")
                .foregroundColor(.white.opacity(0.65))
        }
        .font(.system(size: 10, weight: .medium))
        #endif
    }

    // MARK: - Actions

    private func spin() {
        guard !spinning, !landed else { return }
        spinning = true
        setHandCursor(false)

        // Land the gift segment's center under the top pointer: 5 full turns
        // minus the segment's angular position, with a little jitter so the
        // stop never looks machine-perfect.
        let segAngle = 360.0 / Double(segments.count)
        let target = 5 * 360.0 - (Double(giftIndex) * segAngle + segAngle / 2)
        let jitter = Double.random(in: -segAngle * 0.22...segAngle * 0.22)

        withAnimation(.timingCurve(0.12, 0.75, 0.25, 1.0, duration: 4.2)) {
            rotation = target + jitter
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.35) {
            // Settle the jitter back so the gift slice sits dead-centre.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                rotation = target
            }
            spinning = false
            landed = true
            glowPulse = true
        }
    }

    private func claim() {
        #if DIRECT_BUILD
        NSWorkspace.shared.open(
            URL(string: "https://trypointly.com/buy?plan=lifetime&promo=\(ProManager.spinOfferPromoCode)")!)
        #else
        Task { await proManager.purchaseSpinOffer() }
        #endif
    }

    // MARK: - Wheel drawing

    private var wheelBody: some View {
        ZStack {
            // Slices
            ForEach(segments.indices, id: \.self) { i in
                let seg = segments[i]
                WheelSlice(index: i, count: segments.count)
                    .fill(seg.isGift
                          ? AnyShapeStyle(wheelGradient)
                          : AnyShapeStyle(Color.white.opacity(i.isMultiple(of: 2) ? 0.055 : 0.11)))
                WheelSlice(index: i, count: segments.count)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }

            // Labels
            ForEach(segments.indices, id: \.self) { i in
                let seg = segments[i]
                let segAngle = 360.0 / Double(segments.count)
                let mid = Angle(degrees: -90 + Double(i) * segAngle + segAngle / 2)
                Group {
                    if seg.isGift {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    } else {
                        Text("\(seg.label) OFF")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .rotationEffect(mid + .degrees(90))
                .offset(x: cos(mid.radians) * 108, y: sin(mid.radians) * 108)
            }

            // Rim
            Circle()
                .strokeBorder(wheelGradient, lineWidth: 3)
        }
        .background(Circle().fill(Color(red: 0.05, green: 0.05, blue: 0.11)))
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Shapes

private struct WheelSlice: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        let segAngle = 360.0 / Double(count)
        let start = Angle(degrees: -90 + Double(index) * segAngle)
        let end   = Angle(degrees: -90 + Double(index + 1) * segAngle)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: rect.width / 2,
                 startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
