import SwiftUI

struct OnboardingView: View {
    @State private var step = 0
    let onDismiss: () -> Void

    private let steps: [Step] = [
        Step(
            icon: "pencil.circle.fill",
            title: "Welcome to Pointly",
            body: "Annotate anything on your screen in real time — perfect for presentations, code reviews, and tutorials."
        ),
        Step(
            icon: "keyboard",
            title: "Toggle the Overlay",
            body: "Press ⌘⇧P anywhere to show or hide the drawing overlay. You can change this shortcut in Settings."
        ),
        Step(
            icon: "hand.draw.fill",
            title: "Two Modes",
            body: "Press Tab to switch between Draw mode (annotate freely) and Interact mode (click through to apps underneath). The menu bar icon reflects your current mode."
        ),
        Step(
            icon: "pencil.and.ruler.fill",
            title: "Your Tools",
            body: "Pick from Pen, Highlighter, Marker, Shapes, Text, Laser Pointer, and more from the floating toolbar. Double-tap the canvas to hide or show it."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Slide content
            ZStack {
                ForEach(steps.indices, id: \.self) { i in
                    if i == step {
                        StepCard(step: steps[i])
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: step)
            .frame(height: 290)

            // Progress dots
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: i == step ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
            .padding(.bottom, 28)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if step < steps.count - 1 {
                    Button("Next") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: [])
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(width: 460)
    }

    struct Step {
        let icon: String
        let title: String
        let body: String
    }
}

private struct StepCard: View {
    let step: OnboardingView.Step

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: step.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.accent)
                .padding(.top, 36)

            Text(step.title)
                .font(.title2.bold())

            Text(step.body)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onDismiss: {})
        .frame(width: 460, height: 420)
}
