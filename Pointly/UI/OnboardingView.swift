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
    OBStep(title: "Two Modes, One Tap",
           subtitle: "Switch between Draw mode to annotate freely, and Interact mode to click through to apps underneath."),
    OBStep(title: "Every Tool You Need",
           subtitle: "Pen, Highlighter, Shapes, Text, Laser Pointer and more — all in a sleek floating toolbar right by your side."),
]

// MARK: - Main

struct OnboardingView: View {
    @State private var step = 0
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Full-window glass
            ZStack {
                ObGlass()
                obTint.opacity(0.62)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer()
                    Button("Skip") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.28))
                    .opacity(step < obSteps.count - 1 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: step)
                }
                .padding(.top, 22)
                .padding(.trailing, 28)
                .frame(height: 46)

                // Illustration
                ZStack {
                    Group {
                        switch step {
                        case 0: WelcomeIllustration()
                        case 1: HotkeyIllustration()
                        case 2: ModesIllustration()
                        case 3: ToolsIllustration()
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
                HStack(spacing: 10) {
                    if step > 0 {
                        Button { withAnimation { step -= 1 } } label: {
                            Text("Back")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                                .frame(width: 88, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.07))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    Button {
                        if step < obSteps.count - 1 {
                            withAnimation { step += 1 }
                        } else {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            onDismiss()
                        }
                    } label: {
                        Text(step < obSteps.count - 1 ? "Next" : "Get Started")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(obGradient)
                                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.48),
                                            radius: 16, x: 0, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: step > 0)
                .padding(.horizontal, 40)
                .padding(.bottom, 36)
            }
        }
        .frame(width: 520, height: 580)
        .preferredColorScheme(.dark)
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
            while true {
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

// MARK: - Step 2: Modes

private struct ModesIllustration: View {
    @State private var isInteract = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Full toolbar (draw)
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(obGradient)
                            .frame(width: 30, height: 30)
                            .overlay(Image(systemName: "pencil.tip")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white))

                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 30, height: 30)
                        }
                    }
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
                )
                .scaleEffect(isInteract ? 0.68 : 1.0)
                .opacity(isInteract ? 0 : 1)

                // Mini pill (interact)
                HStack(spacing: 0) {
                    VStack(spacing: 2.5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 14, height: 2)
                        }
                    }
                    .padding(.horizontal, 10)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 0.8)
                        .padding(.vertical, 8)

                    Image(systemName: "pencil.tip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(obGradient)
                        .frame(width: 36, height: 36)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 0.8)
                        .padding(.vertical, 8)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(obGradient)
                            .frame(width: 6, height: 6)
                        Text("INTERACT")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 19)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 19)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 5)
                )
                .scaleEffect(isInteract ? 1.0 : 0.72)
                .opacity(isInteract ? 1 : 0)
            }
            .animation(.spring(response: 0.46, dampingFraction: 0.76), value: isInteract)

            // Mode labels
            HStack(spacing: 28) {
                modeLabel("Draw", active: !isInteract)
                modeLabel("Interact", active: isInteract)
            }
        }
        .task {
            while true {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                isInteract = true
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                isInteract = false
            }
        }
    }

    private func modeLabel(_ text: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? AnyShapeStyle(obGradient) : AnyShapeStyle(Color.white.opacity(0.2)))
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .white : .white.opacity(0.3))
        }
        .animation(.easeInOut(duration: 0.3), value: active)
    }
}

// MARK: - Step 3: Tools

private struct ToolsIllustration: View {
    @State private var selectedIndex = 0
    @State private var strokeProgress: CGFloat = 0

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

            // Animated stroke preview
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 200, height: 38)

                Path { p in
                    p.move(to: CGPoint(x: 16, y: 19))
                    p.addCurve(
                        to: CGPoint(x: 184, y: 19),
                        control1: CGPoint(x: 64,  y: 6),
                        control2: CGPoint(x: 136, y: 32)
                    )
                }
                .trim(from: 0, to: strokeProgress)
                .stroke(obGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 200, height: 38)
            }
        }
        .task {
            while true {
                strokeProgress = 0
                withAnimation(.easeInOut(duration: 0.9)) { strokeProgress = 1 }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                selectedIndex = (selectedIndex + 1) % tools.count
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
}
