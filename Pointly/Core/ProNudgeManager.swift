import AppKit
import SwiftUI

// MARK: - Nudge type

private enum NudgeType {
    case milestone(count: Int)
    case longSession

    var iconName: String {
        switch self {
        case .milestone: return "wand.and.stars"
        case .longSession: return "sparkles"
        }
    }

    var title: String {
        switch self {
        case .milestone(let c): return "You've used Pointly \(c) times"
        case .longSession: return "That was a long session."
        }
    }

    var body: String {
        switch self {
        case .milestone: return "Looks like it's working for you. Pro tools like Laser Pointer and Spotlight are one tap away."
        case .longSession: return "Pro tools like Laser Pointer and Spotlight are one tap away."
        }
    }
}

// MARK: - Glass

private struct NudgeGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: - Card view

private let nudgeGradient = LinearGradient(
    colors: [Color(hex: "#F4644D") ?? .orange, Color(hex: "#E9458C") ?? .pink],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private struct ProNudgeCard: View {
    let type: NudgeType
    let onUnlock: () -> Void
    let onDismiss: () -> Void

    @State private var hoverUnlock = false
    @State private var hoverClose  = false
    @State private var progress: CGFloat = 1.0

    var body: some View {
        ZStack {
            ZStack {
                NudgeGlass()
                Color(red: 0.06, green: 0.06, blue: 0.14).opacity(0.72)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(nudgeGradient)
                            .frame(width: 38, height: 38)
                        Image(systemName: type.iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(type.body)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.50))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Unlock Pro →") { onUnlock() }
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(nudgeGradient)
                            .buttonStyle(.plain)
                            .opacity(hoverUnlock ? 0.7 : 1.0)
                            .animation(.easeInOut(duration: 0.12), value: hoverUnlock)
                            .onHover { hoverUnlock = $0 }
                    }

                    Spacer(minLength: 0)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(hoverClose ? 0.6 : 0.25))
                            .animation(.easeInOut(duration: 0.12), value: hoverClose)
                    }
                    .buttonStyle(.plain)
                    .onHover { hoverClose = $0 }
                }
                .padding(14)

                // Auto-dismiss progress bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(nudgeGradient)
                        .frame(width: geo.size.width * progress, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 2)
                .onAppear {
                    withAnimation(.linear(duration: 8)) { progress = 0 }
                }
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Window presentation

private var nudgePanel: NSPanel?
private var autoDismissWork: DispatchWorkItem?

@MainActor
private func showNudgePanel(type: NudgeType, onUnlock: @escaping () -> Void) {
    nudgePanel?.close()
    autoDismissWork?.cancel()

    let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let dismiss = {
        nudgePanel?.close()
        nudgePanel = nil
        autoDismissWork?.cancel()
    }

    let card = ProNudgeCard(
        type: type,
        onUnlock: { dismiss(); onUnlock() },
        onDismiss: dismiss
    )

    let pad: CGFloat = 24
    let hosting = NSHostingView(rootView: card.padding(pad))
    let fit = hosting.fittingSize
    hosting.frame = CGRect(origin: .zero, size: fit)
    panel.setContentSize(fit)
    panel.contentView?.addSubview(hosting)

    // Bottom-right of main screen, above the Dock
    if let screen = NSScreen.main {
        let margin: CGFloat = 16
        let x = screen.visibleFrame.maxX - fit.width - margin
        let y = screen.visibleFrame.minY + margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.25
        panel.animator().alphaValue = 1
    }
    nudgePanel = panel

    // Auto-dismiss after 8 seconds
    let work = DispatchWorkItem { dismiss() }
    autoDismissWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
}

// MARK: - Manager

enum ProNudgeManager {
    private static let sessionCountKey         = "proNudgeSessionCount"
    private static let milestoneShownKey       = "proNudgeMilestoneShown"
    private static let lastLongSessionNudgeKey = "proNudgeLastLongSession"

    private static let milestoneThreshold: Int         = 7
    private static let longSessionThreshold: TimeInterval = 5 * 60
    private static let longSessionCooldown: TimeInterval  = 3 * 24 * 3600

    static func recordSession(duration: TimeInterval, showPaywall: @escaping () -> Void) {
        guard !ProManager.shared.isPro else { return }

        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: sessionCountKey) + 1
        defaults.set(count, forKey: sessionCountKey)

        // Milestone nudge — one-shot at exactly the threshold
        if count == milestoneThreshold, !defaults.bool(forKey: milestoneShownKey) {
            defaults.set(true, forKey: milestoneShownKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showNudgePanel(type: .milestone(count: count), onUnlock: showPaywall)
            }
            return
        }

        // Long session nudge — throttled to once every 3 days
        guard duration >= longSessionThreshold else { return }
        let lastShown = defaults.object(forKey: lastLongSessionNudgeKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastShown) > longSessionCooldown else { return }
        defaults.set(Date(), forKey: lastLongSessionNudgeKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showNudgePanel(type: .longSession, onUnlock: showPaywall)
        }
    }
}
