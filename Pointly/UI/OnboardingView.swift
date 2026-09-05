import SwiftUI
import AppKit

// MARK: - Brand

private let obGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink,
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let obTint = Color(red: 0.06, green: 0.06, blue: 0.14)

// MARK: - Glass

private struct ObGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: - Step data

private struct OBStep {
    let title: String
    let subtitle: String
}

private let obSteps: [OBStep] = [
    OBStep(title: "Welcome to Pointly",
           subtitle: "Annotate anything on your screen in real time — perfect for presentations, code reviews, and live demos."),
    OBStep(title: "Activate with a Hotkey",
           subtitle: "Press ⌘⇧P anywhere to show or hide the drawing overlay. You can change this shortcut in Settings."),
    OBStep(title: "Your Command Center",
           subtitle: "Click the pencil icon in your menu bar to access Settings, the Countdown Timer, Whiteboard Canvas and more — anytime."),
    OBStep(title: "Two Modes, One Tap",
           subtitle: "Switch between Draw mode to annotate freely, and Interact mode to click through to apps underneath."),
    OBStep(title: "Every Tool You Need",
           subtitle: "Pen, Marker, Shapes, Stamps, Magnifier and more — all in a floating toolbar you can move and resize freely."),
    OBStep(title: "Shapes & Color on Hover",
           subtitle: "Hover the shapes chip to reveal 8 shape styles and a full color palette — the panel closes the moment your cursor moves away."),
    OBStep(title: "Unlock Pointly Pro",
           subtitle: "Blur Brush, Laser Pointer, Spotlight, Callout, Step Badge and more — powerful tools built for professionals."),
]

// MARK: - Main

struct OnboardingView: View {
    @State private var step = 0
    @State private var hoverSkip     = false
    @State private var hoverBack     = false
    @State private var hoverNext     = false
    @State private var hoverAnnual   = false
    @State private var hoverLifetime = false
    @State private var hoverFree     = false
    @ObservedObject private var proManager = ProManager.shared
    let onDismiss: () -> Void
    var onContinueFree: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Full-window glass
            ZStack {
                ObGlass()
                obTint.opacity(0.62)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar spacer (Skip removed)
                Spacer().frame(height: 46)

                // Illustration
                ZStack {
                    Group {
                        switch step {
                        case 0: WelcomeIllustration()
                        case 1: HotkeyIllustration()
                        case 2: MenuBarIllustration()
                        case 3: ModesIllustration()
                        case 4: ToolsIllustration()
                        case 5: ShapesHoverIllustration()
                        case 6: ProIllustration()
                        default: EmptyView()
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.84).combined(with: .opacity),
                        removal:   .scale(scale: 1.1 ).combined(with: .opacity)
                    ))
                }
                .frame(height: 210)
                .animation(.spring(response: 0.44, dampingFraction: 0.78), value: step)

                // Text
                VStack(spacing: 10) {
                    Text(obSteps[step].title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(obSteps[step].subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.48))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                        .padding(.horizontal, 50)
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: step)
                .padding(.top, 26)
                .padding(.bottom, 28)

                // Progress dots
                HStack(spacing: 7) {
                    ForEach(obSteps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == step
                                  ? AnyShapeStyle(obGradient)
                                  : AnyShapeStyle(Color.white.opacity(0.18)))
                            .frame(width: i == step ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: step)
                    }
                }
                .padding(.bottom, 24)

                // Navigation
                if step == obSteps.count - 1 {
                    // Pro upsell step — two plan buttons + continue free
                    VStack(spacing: 10) {
                        // Pro (annual)
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            onDismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                NotificationCenter.default.post(name: .showPaywallForPlan, object: ProPlan.annual)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Go Pro")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("\(proManager.product(for: .annual)?.displayPrice ?? "$12.99") / year")
                                        .font(.system(size: 11))
                                        .opacity(0.7)
                                }
                                Spacer()
                                Text("Most Popular")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.2)))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(obGradient)
                                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(hoverAnnual ? 0.75 : 0.5),
                                            radius: hoverAnnual ? 22 : 16, x: 0, y: 6)
                            )
                            .scaleEffect(hoverAnnual ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.14), value: hoverAnnual)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverAnnual = $0 }
                        .keyboardShortcut(.return, modifiers: [])

                        // Pro+ (lifetime)
                        Button {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            onDismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                NotificationCenter.default.post(name: .showPaywallForPlan, object: ProPlan.lifetime)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Get Pro+")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("\(proManager.product(for: .lifetime)?.displayPrice ?? "$39.99") · One-time")
                                        .font(.system(size: 11))
                                        .opacity(0.65)
                                }
                                Spacer()
                                Text("Best Value")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.12)))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(hoverLifetime ? 0.11 : 0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.white.opacity(hoverLifetime ? 0.32 : 0.18), lineWidth: 0.8)
                                    )
                            )
                            .scaleEffect(hoverLifetime ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.14), value: hoverLifetime)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverLifetime = $0 }

                        Button {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            onDismiss()
                            onContinueFree?()
                        } label: {
                            Text("Continue Free")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(hoverFree ? 0.55 : 0.32))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .animation(.easeInOut(duration: 0.14), value: hoverFree)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverFree = $0 }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    HStack(spacing: 10) {
                        if step > 0 {
                            Button { withAnimation { step -= 1 } } label: {
                                Text("Back")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(hoverBack ? 0.70 : 0.45))
                                    .frame(width: 88, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(hoverBack ? 0.11 : 0.07))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.white.opacity(hoverBack ? 0.22 : 0.12), lineWidth: 0.8))
                                    )
                                    .scaleEffect(hoverBack ? 1.03 : 1.0)
                                    .animation(.easeInOut(duration: 0.14), value: hoverBack)
                            }
                            .buttonStyle(.plain)
                            .onHover { hoverBack = $0 }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        Button {
                            withAnimation { step += 1 }
                        } label: {
                            Text("Next")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(obGradient)
                                        .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(hoverNext ? 0.72 : 0.48),
                                                radius: hoverNext ? 22 : 16, x: 0, y: 6)
                                )
                                .scaleEffect(hoverNext ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 0.14), value: hoverNext)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverNext = $0 }
                        .keyboardShortcut(.return, modifiers: [])
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: step > 0)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)
                }
            }
            // Keyboard navigation — arrow keys step through slides
            Button("") { withAnimation { if step > 0 { step -= 1 } } }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .hidden()
            Button("") {
                withAnimation {
                    if step < obSteps.count - 1 { step += 1 }
                }
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .hidden()
        }
        .frame(width: 520, height: 580)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Step 5: Shapes hover illustration

private struct ShapesHoverIllustration: View {
    @State private var cursorVisible  = false
    @State private var cursorPos      = CGPoint(x: 50, y: -60)
    @State private var chipGlow       = false
    @State private var expandH: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var selectedShape  = -1
    @State private var selectedColor  = -1

    private let shapes     = ["square", "circle", "triangle", "diamond"]
    private let drawIcons  = ["pencil.tip", "highlighter", "paintbrush.fill",
                               "eraser", "text.cursor", "scissors"]
    private let lineIcons  = ["arrow.up.right", "line.diagonal"]
    private let swatchColors: [Color] = [
        .white,
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#E9458C") ?? .pink,
        Color(hex: "#4FACFE") ?? .blue,
        Color(hex: "#34D399") ?? .green,
        Color(hex: "#FFD166") ?? .yellow,
    ]
    private let expandedH: CGFloat = 76

    var body: some View {
        // Toolbar sits at the top of the ZStack; expansion grows downward
        // into free space — the bottom row clips out naturally (realistic).
        ZStack {
            VStack(spacing: 0) {
                miniToolbar
                Spacer(minLength: 0)
            }

            Image(systemName: "cursorarrow")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.65), radius: 3, x: 1, y: 1)
                .offset(x: cursorPos.x, y: cursorPos.y)
                .opacity(cursorVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.65), value: cursorPos)
                .animation(.easeInOut(duration: 0.25), value: cursorVisible)
        }
        .task { await runLoop() }
    }

    // MARK: - Mini floating toolbar

    private var miniToolbar: some View {
        VStack(spacing: 0) {
            // Drag handle
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(Color.white.opacity(0.22))
                        .frame(width: 18, height: 2.5)
                }
            }
            .frame(height: 16)

            sep

            // DRAW mode pill
            HStack(spacing: 4) {
                Circle().fill(obGradient).frame(width: 5, height: 5)
                Text("DRAW")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9)).tracking(0.6)
            }
            .frame(maxWidth: .infinity).frame(height: 16)
            .background(RoundedRectangle(cornerRadius: 6).fill(obGradient.opacity(0.28)))

            sep

            // Draw tools — 3 × 2 mini grid (static, no hover state)
            VStack(spacing: 2) {
                ForEach([[0,1,2],[3,4,5]], id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(row, id: \.self) { idx in
                            Image(systemName: drawIcons[idx])
                                .font(.system(size: 7.5))
                                .foregroundColor(.white.opacity(0.45))
                                .frame(width: 15, height: 15)
                                .background(RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.06)))
                        }
                    }
                }
            }
            .padding(.vertical, 3)

            sep

            // Line tools
            HStack(spacing: 2) {
                ForEach(lineIcons, id: \.self) { icon in
                    Image(systemName: icon).font(.system(size: 7.5))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 15, height: 15)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                }
            }
            .padding(.vertical, 3)

            sep

            // ── Shapes & Color chip ──
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Image(systemName: selectedShape >= 0 ? shapes[selectedShape] : "square")
                        .font(.system(size: 10, weight: selectedShape >= 0 ? .semibold : .regular))
                        .foregroundStyle(
                            (chipGlow || selectedShape >= 0)
                                ? AnyShapeStyle(obGradient)
                                : AnyShapeStyle(Color.white.opacity(0.45))
                        )
                        .frame(maxWidth: .infinity, minHeight: 22)

                    Circle()
                        .fill(selectedColor >= 0 ? swatchColors[selectedColor] : Color.white)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.7
                        ))
                        .shadow(color: (selectedColor >= 0 ? swatchColors[selectedColor] : Color.white)
                                    .opacity(chipGlow ? 0.9 : 0.2), radius: chipGlow ? 5 : 1)
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(chipGlow ? Color.white.opacity(0.13) : Color.white.opacity(0.07))
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(chipGlow ? 0.34 : 0.18),
                                             Color.white.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ), lineWidth: 0.7
                            )
                    }
                )
                .animation(.easeOut(duration: 0.15), value: chipGlow)

                // Expanding panel below chip
                VStack(spacing: 0) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).padding(.vertical, 2)

                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            ForEach(shapes.indices, id: \.self) { i in
                                Image(systemName: shapes[i])
                                    .font(.system(size: 7, weight: selectedShape == i ? .semibold : .regular))
                                    .foregroundStyle(
                                        selectedShape == i
                                            ? AnyShapeStyle(obGradient)
                                            : AnyShapeStyle(Color.white.opacity(0.5))
                                    )
                                    .frame(width: 17, height: 14)
                                    .background(RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedShape == i
                                              ? AnyShapeStyle(obGradient.opacity(0.22))
                                              : AnyShapeStyle(Color.white.opacity(0.06))))
                                    .scaleEffect(selectedShape == i ? 1.12 : 1.0)
                                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: selectedShape == i)
                            }
                        }
                        HStack(spacing: 3) {
                            ForEach(shapes.indices, id: \.self) { i in
                                Image(systemName: shapes[i] + ".fill")
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.35))
                                    .frame(width: 17, height: 14)
                                    .background(RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.05)))
                            }
                        }
                    }
                    .padding(.vertical, 2)

                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).padding(.vertical, 2)

                    HStack(spacing: 4) {
                        ForEach(swatchColors.indices, id: \.self) { i in
                            Circle().fill(swatchColors[i]).frame(width: 8, height: 8)
                                .overlay(Circle().strokeBorder(
                                    selectedColor == i
                                        ? AnyShapeStyle(obGradient)
                                        : AnyShapeStyle(Color.white.opacity(0.18)),
                                    lineWidth: selectedColor == i ? 1.2 : 0.5
                                ))
                                .scaleEffect(selectedColor == i ? 1.35 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedColor == i)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .opacity(contentOpacity)
                .frame(height: expandH, alignment: .top)
                .clipped()
            }

            sep

            // Undo / Redo
            HStack(spacing: 2) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 7.5))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 15, height: 15)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                Image(systemName: "arrow.uturn.forward").font(.system(size: 7.5))
                    .foregroundColor(.white.opacity(0.22))
                    .frame(width: 15, height: 15)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
            }
            .padding(.vertical, 3)

            // Export / Clear
            HStack(spacing: 2) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 7.5))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 15, height: 15)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                Image(systemName: "trash").font(.system(size: 7.5))
                    .foregroundStyle(AnyShapeStyle((Color(hex: "#F4644D") ?? .orange).opacity(0.7)))
                    .frame(width: 15, height: 15)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
            }
            .padding(.bottom, 3)
        }
        .frame(width: 60)
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.14).opacity(0.97))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.8
                    ))
                .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 8)
        )
    }

    private var sep: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.7).padding(.vertical, 3)
    }

    // MARK: - Animation loop
    //
    // Cursor y offsets: ZStack center = 0, toolbar top-aligned at -105.
    //   Chip center (collapsed) : +27
    //   Shapes outline row      : +52  (after expansion)
    //   Color row               : +89  (after expansion)

    private func runLoop() async {
        while !Task.isCancelled {
            // Reset — no animation
            cursorPos      = CGPoint(x: 50, y: 27)
            chipGlow       = false; expandH = 0; contentOpacity = 0
            selectedShape  = -1; selectedColor = -1
            cursorVisible  = false

            try? await Task.sleep(nanoseconds: 500_000_000)

            // Cursor appears off to the right at chip height, then glides in
            withAnimation(.easeInOut(duration: 0.25)) { cursorVisible = true }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeInOut(duration: 0.65)) { cursorPos = CGPoint(x: -8, y: 27) }
            try? await Task.sleep(nanoseconds: 700_000_000)

            // Chip lights up
            withAnimation { chipGlow = true }
            try? await Task.sleep(nanoseconds: 160_000_000)

            // Panel springs open
            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) { expandH = expandedH }
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.easeOut(duration: 0.18)) { contentOpacity = 1 }
            try? await Task.sleep(nanoseconds: 700_000_000)

            // Move to outline shapes row → pick triangle (index 2, center x ≈ +10)
            withAnimation(.easeInOut(duration: 0.55)) { cursorPos = CGPoint(x: 10, y: 52) }
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation { selectedShape = 2 }
            try? await Task.sleep(nanoseconds: 650_000_000)

            // Move to color row → pick blue (index 3, cursor tip lands at blue)
            withAnimation(.easeInOut(duration: 0.55)) { cursorPos = CGPoint(x: -6, y: 89) }
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation { selectedColor = 3 }
            try? await Task.sleep(nanoseconds: 900_000_000)

            // Cursor drifts away → panel collapses
            withAnimation(.easeInOut(duration: 0.55)) { cursorPos = CGPoint(x: 50, y: 27); chipGlow = false }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeIn(duration: 0.10)) { contentOpacity = 0 }
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) { expandH = 0 }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 0.25)) { cursorVisible = false }
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }
}

// MARK: - Step 6: Pro upsell

private struct ProIllustration: View {
    @State private var float = false
    @State private var glow  = false

    private let proTools: [(icon: String, label: String)] = [
        ("camera.filters",  "Blur"),
        ("laser.burst",     "Laser"),
        ("rays",            "Spotlight"),
        ("circle.dotted",   "Dot Pen"),
        ("scissors",        "Cut & Move"),
        ("1.circle",        "Step Badge"),
        ("text.bubble",     "Callout"),
    ]

    var body: some View {
        ZStack {
            // Outer ring — scaled up slightly to fit 7 tools
            Circle()
                .stroke(obGradient.opacity(0.25), lineWidth: 1)
                .frame(width: 186, height: 186)
                .scaleEffect(glow ? 1.06 : 0.94)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: glow)

            // Pro tool icons orbiting the crown
            ForEach(proTools.indices, id: \.self) { i in
                let angle = Double(i) * (360.0 / Double(proTools.count)) - 90
                let rad   = Double.pi * angle / 180
                let r: CGFloat = 84
                let x = r * CGFloat(cos(rad))
                let y = r * CGFloat(sin(rad))

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: proTools[i].icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(obGradient)
                }
                .offset(x: x, y: y + (float ? -4 : 4))
                .animation(
                    .easeInOut(duration: 1.8 + Double(i) * 0.22)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.28),
                    value: float
                )
            }

            // Central crown badge
            ZStack {
                Circle()
                    .fill(obGradient)
                    .frame(width: 74, height: 74)
                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.65),
                            radius: 22, x: 0, y: 8)

                Image(systemName: "crown.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(y: float ? -5 : 5)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: float)

            // Sparkles
            let sparkles: [(CGFloat, CGFloat, Double)] = [
                (-90, -30, 0.0), (88, -48, 0.4), (-76, 52, 0.7), (80, 48, 0.2)
            ]
            ForEach(sparkles.indices, id: \.self) { i in
                let (dx, dy, delay) = sparkles[i]
                Image(systemName: i % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: i % 2 == 0 ? 11 : 7))
                    .foregroundStyle(obGradient)
                    .offset(x: dx, y: dy + (float ? -4 : 4))
                    .opacity(float ? 0.9 : 0.15)
                    .animation(
                        .easeInOut(duration: 1.9 + Double(i) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                        value: float
                    )
            }
        }
        .onAppear { float = true; glow = true }
    }
}

// MARK: - Menu Bar Hint (shown once via NSPopover after first onboarding)

struct MenuBarHintView: View {
    private let gradient = LinearGradient(
        colors: [Color(hex: "#F4644D") ?? .orange, Color(hex: "#E9458C") ?? .pink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((Color(hex: "#F4644D") ?? .orange).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(gradient)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Everything lives up here")
                    .font(.system(size: 13, weight: .semibold))
                Text("Settings, Timer, Canvas & more")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 272)
    }
}

// MARK: - Step 2: Menu Bar

private struct MenuBarIllustration: View {
    @State private var iconHighlighted = false
    @State private var menuOpen        = false
    @State private var itemsShown      = 0

    private let items: [(icon: String, label: String)] = [
        ("rectangle.on.rectangle.angled", "Whiteboard Canvas"),
        ("timer",                          "Countdown Timer"),
        ("gearshape",                      "Settings"),
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Spacer().frame(height: 18)

            // ── Menu bar strip ──
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))

                // Left: fake system labels
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 11))
                    Text("Pointly")
                        .font(.system(size: 11, weight: .semibold))
                    Text("File")
                        .font(.system(size: 11))
                    Text("Edit")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.35))
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: mock system icons + Pointly icon
                HStack(spacing: 10) {
                    Image(systemName: "wifi")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))
                    Image(systemName: "battery.100")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))

                    // Pointly icon — highlights when "clicked"
                    ZStack {
                        if iconHighlighted {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 28, height: 22)
                        }
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(
                                iconHighlighted
                                    ? AnyShapeStyle(obGradient)
                                    : AnyShapeStyle(Color.white.opacity(0.70))
                            )
                    }
                    .animation(.easeInOut(duration: 0.14), value: iconHighlighted)
                }
                .padding(.trailing, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)

            // ── Dropdown menu ──
            if menuOpen {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<min(itemsShown, items.count), id: \.self) { i in
                        HStack(spacing: 9) {
                            Image(systemName: items[i].icon)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(obGradient)
                                .frame(width: 16, alignment: .center)
                            Text(items[i].label)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.88))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)

                        if i < items.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .frame(width: 192)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(white: 0.13))
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.50), radius: 18, x: 0, y: 8)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.88, anchor: .topTrailing).combined(with: .opacity),
                    removal:   .scale(scale: 0.88, anchor: .topTrailing).combined(with: .opacity)
                ))
                .padding(.top, 4)
                .padding(.trailing, 14)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation(.easeIn(duration: 0.14)) { iconHighlighted = true }
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.74)) { menuOpen = true }
                for _ in 0..<items.count {
                    try? await Task.sleep(nanoseconds: 130_000_000)
                    withAnimation(.easeOut(duration: 0.11)) { itemsShown += 1 }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeOut(duration: 0.18)) { menuOpen = false; iconHighlighted = false }
                try? await Task.sleep(nanoseconds: 320_000_000)
                itemsShown = 0
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeIllustration: View {
    @State private var pulse = false
    @State private var float = false

    var body: some View {
        ZStack {
            // Pulsing rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                (Color(hex: "#F4644D") ?? .orange).opacity(0.45),
                                (Color(hex: "#E9458C") ?? .pink).opacity(0.12),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: 96 + CGFloat(i) * 40, height: 96 + CGFloat(i) * 40)
                    .scaleEffect(pulse ? 1.2 : 0.88)
                    .opacity(pulse ? 0 : 0.65)
                    .animation(
                        .easeOut(duration: 2.2)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.65),
                        value: pulse
                    )
            }

            // Main icon circle
            ZStack {
                Circle()
                    .fill(obGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.55), radius: 26, x: 0, y: 10)

                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }
            .offset(y: float ? -7 : 6)
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: float)

            // Sparkles
            let sparkles: [(String, CGFloat, CGFloat, Double)] = [
                ("sparkle",   -80, -38, 0.0),
                ("sparkle",    76, -54, 0.5),
                ("star.fill", -68,  50, 0.8),
                ("sparkle",    70,  46, 0.3),
            ]
            ForEach(sparkles.indices, id: \.self) { i in
                let (icon, dx, dy, delay) = sparkles[i]
                Image(systemName: icon)
                    .font(.system(size: i == 2 ? 8 : 11))
                    .foregroundStyle(obGradient)
                    .offset(x: dx, y: dy + (float ? -5 : 5))
                    .opacity(float ? 0.85 : 0.2)
                    .animation(
                        .easeInOut(duration: 2.0 + Double(i) * 0.25)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                        value: float
                    )
            }
        }
        .onAppear {
            pulse = true
            float = true
        }
    }
}

// MARK: - Step 1: Hotkey

private struct HotkeyIllustration: View {
    @State private var pressed = false
    @State private var toolbarVisible = false

    var body: some View {
        VStack(spacing: 22) {
            // Key caps
            HStack(spacing: 14) {
                ForEach(["⌘", "⇧", "P"].indices, id: \.self) { i in
                    KeyCapView(label: ["⌘", "⇧", "P"][i], pressed: pressed)
                        .animation(
                            .spring(response: 0.22, dampingFraction: 0.6)
                            .delay(pressed ? Double(i) * 0.06 : 0),
                            value: pressed
                        )
                }
            }

            // Fake toolbar sliding in
            HStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(obGradient)
                    .frame(width: 30, height: 30)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.8, height: 22)

                HStack(spacing: 6) {
                    ForEach(["highlighter", "paintbrush.fill", "eraser", "arrow.up.right"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(width: 26, height: 26)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.13), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
            )
            .scaleEffect(toolbarVisible ? 1 : 0.82)
            .opacity(toolbarVisible ? 1 : 0)
            .offset(x: toolbarVisible ? 0 : -18)
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: toolbarVisible)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                pressed = true
                try? await Task.sleep(nanoseconds: 350_000_000)
                toolbarVisible = true
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                pressed = false
                try? await Task.sleep(nanoseconds: 600_000_000)
                toolbarVisible = false
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}

private struct KeyCapView: View {
    let label: String
    let pressed: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 58, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(pressed ? AnyShapeStyle(obGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(Color.white.opacity(pressed ? 0 : 0.2), lineWidth: 0.8))
                    .shadow(color: pressed ? (Color(hex: "#F4644D") ?? .orange).opacity(0.55) : .clear,
                            radius: 14, x: 0, y: 5)
            )
            .scaleEffect(pressed ? 0.90 : 1.0)
    }
}

private struct WideKeyCapView: View {
    let label: String
    let pressed: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 82, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(pressed ? AnyShapeStyle(obGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(Color.white.opacity(pressed ? 0 : 0.2), lineWidth: 0.8))
                    .shadow(color: pressed ? (Color(hex: "#F4644D") ?? .orange).opacity(0.55) : .clear,
                            radius: 14, x: 0, y: 5)
            )
            .scaleEffect(pressed ? 0.90 : 1.0)
    }
}

// MARK: - Step 2: Modes

private struct ModesIllustration: View {
    @State private var isInteract = false
    @State private var keysPressed = false

    private let toolIcons = ["pencil.tip", "highlighter", "eraser"]

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Draw mode: single-column toolbar pill + size bar
                HStack(spacing: 5) {
                    VStack(spacing: 4) {
                        // "Draw" header badge
                        RoundedRectangle(cornerRadius: 6)
                            .fill(obGradient)
                            .frame(width: 40, height: 17)
                            .overlay(
                                Text("Draw")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        // Tool buttons (single column)
                        ForEach(toolIcons.indices, id: \.self) { i in
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(i == 0
                                          ? AnyShapeStyle(obGradient.opacity(0.85))
                                          : AnyShapeStyle(Color.white.opacity(0.06)))
                                    .frame(width: 34, height: 18)
                                Image(systemName: toolIcons[i])
                                    .font(.system(size: 10, weight: i == 0 ? .semibold : .regular))
                                    .foregroundColor(i == 0 ? .white : .white.opacity(0.3))
                            }
                            .frame(width: 34, height: 18)
                        }
                        // Color dots
                        HStack(spacing: 3) {
                            Circle().fill(Color.white.opacity(0.85)).frame(width: 6, height: 6)
                            Circle().fill(Color.orange.opacity(0.85)).frame(width: 6, height: 6)
                            Circle().fill((Color(hex: "#E9458C") ?? .pink).opacity(0.85)).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    )

                    // Thin size bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
                        .frame(width: 10, height: 62)
                }
                .scaleEffect(isInteract ? 0.72 : 1.0)
                .opacity(isInteract ? 0 : 1)
                .animation(.spring(response: 0.46, dampingFraction: 0.76), value: isInteract)

                // Interact mode pill
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 0.8, height: 20)
                    HStack(spacing: 5) {
                        Circle().fill(obGradient).frame(width: 5, height: 5)
                        Text("INTERACT")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(0.5)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                )
                .scaleEffect(isInteract ? 1.0 : 0.72)
                .opacity(isInteract ? 1 : 0)
                .animation(.spring(response: 0.46, dampingFraction: 0.76), value: isInteract)
            }
            .frame(height: 114)

            // ⌘ + Esc key caps
            HStack(spacing: 8) {
                KeyCapView(label: "⌘", pressed: keysPressed)
                WideKeyCapView(label: "Esc", pressed: keysPressed)
            }
            .scaleEffect(0.68)
            .frame(height: 42)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                keysPressed = true
                try? await Task.sleep(nanoseconds: 300_000_000)
                isInteract = true
                try? await Task.sleep(nanoseconds: 200_000_000)
                keysPressed = false
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                keysPressed = true
                try? await Task.sleep(nanoseconds: 300_000_000)
                isInteract = false
                try? await Task.sleep(nanoseconds: 200_000_000)
                keysPressed = false
            }
        }
    }
}

// MARK: - Step 3: Tools

private struct ToolsIllustration: View {
    @State private var selectedIndex = 0
    @State private var progress: CGFloat = 0

    private let tools: [(icon: String, name: String)] = [
        ("pencil.tip",      "Pen"),
        ("highlighter",     "Highlighter"),
        ("paintbrush.fill", "Marker"),
        ("eraser",          "Eraser"),
        ("text.cursor",     "Text"),
        ("arrow.up.right",  "Arrow"),
    ]

    var body: some View {
        VStack(spacing: 18) {
            // 2×3 tool grid
            VStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            let tool = tools[idx]
                            let active = idx == selectedIndex
                            RoundedRectangle(cornerRadius: 9)
                                .fill(active
                                      ? AnyShapeStyle(obGradient)
                                      : AnyShapeStyle(Color.white.opacity(0.07)))
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: tool.icon)
                                        .font(.system(size: 15, weight: active ? .semibold : .regular))
                                        .foregroundColor(active ? .white : .white.opacity(0.38))
                                )
                                .shadow(
                                    color: active ? (Color(hex: "#F4644D") ?? .orange).opacity(0.5) : .clear,
                                    radius: 9, x: 0, y: 3
                                )
                                .scaleEffect(active ? 1.08 : 1.0)
                                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: active)
                        }
                    }
                }
            }

            // Tool-specific animated preview
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 200, height: 44)

                toolPreview(for: selectedIndex, progress: progress)
                    .frame(width: 200, height: 44)
                    .id(selectedIndex)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        }
        .task {
            while !Task.isCancelled {
                progress = 0
                withAnimation(.easeInOut(duration: 0.85)) { progress = 1 }
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                selectedIndex = (selectedIndex + 1) % tools.count
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    @ViewBuilder
    private func toolPreview(for index: Int, progress: CGFloat) -> some View {
        switch index {
        case 0: // Pen — thin organic curve
            Path { p in
                p.move(to: CGPoint(x: 14, y: 22))
                p.addCurve(to: CGPoint(x: 186, y: 22),
                           control1: CGPoint(x: 60, y: 6),
                           control2: CGPoint(x: 130, y: 38))
            }
            .trim(from: 0, to: progress)
            .stroke(obGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        case 1: // Highlighter — thick translucent sweep
            Path { p in
                p.move(to: CGPoint(x: 14, y: 22))
                p.addLine(to: CGPoint(x: 186, y: 22))
            }
            .trim(from: 0, to: progress)
            .stroke(
                LinearGradient(colors: [(Color(hex: "#FFD166") ?? .yellow).opacity(0.55),
                                        (Color(hex: "#FF8C42") ?? .orange).opacity(0.45)],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )

        case 2: // Marker — bold solid stroke
            Path { p in
                p.move(to: CGPoint(x: 14, y: 26))
                p.addCurve(to: CGPoint(x: 186, y: 18),
                           control1: CGPoint(x: 72, y: 10),
                           control2: CGPoint(x: 130, y: 34))
            }
            .trim(from: 0, to: progress)
            .stroke(obGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))

        case 3: // Eraser — dashed ghost line
            Path { p in
                p.move(to: CGPoint(x: 14, y: 22))
                p.addLine(to: CGPoint(x: 186, y: 22))
            }
            .trim(from: 0, to: progress)
            .stroke(Color.white.opacity(0.25),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))

        case 4: // Text — typed label fading in
            Text("Hello, world!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(obGradient)
                .opacity(progress)
                .scaleEffect(0.8 + progress * 0.2, anchor: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

        case 5: // Arrow — line + arrowhead
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 14, y: 22))
                    p.addLine(to: CGPoint(x: 166, y: 22))
                }
                .trim(from: 0, to: progress)
                .stroke(obGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                Path { p in
                    p.move(to: CGPoint(x: 152, y: 11))
                    p.addLine(to: CGPoint(x: 186, y: 22))
                    p.addLine(to: CGPoint(x: 152, y: 33))
                }
                .trim(from: 0, to: max(0, progress * 2 - 0.8))
                .stroke(obGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

        default:
            EmptyView()
        }
    }
}
