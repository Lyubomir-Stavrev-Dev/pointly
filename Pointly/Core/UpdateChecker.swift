import AppKit
import SwiftUI

// MARK: - Brand

private let updateGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink,
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let updateTint = Color(red: 0.06, green: 0.06, blue: 0.14)

private struct UpdateGlass: NSViewRepresentable {
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

struct UpdateCardView: View {
    let newVersion: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    @State private var hoverUpdate = false
    @State private var hoverLater  = false

    // Grab the real app icon at runtime
    private var appIcon: NSImage {
        NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    var body: some View {
        ZStack {
            ZStack {
                UpdateGlass()
                updateTint.opacity(0.70)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Icon + title row ──────────────────────────────────────
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        // App icon
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                        // Badge
                        ZStack {
                            Circle()
                                .fill(updateGradient)
                                .frame(width: 22, height: 22)
                                .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.6),
                                        radius: 6, x: 0, y: 2)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 6, y: 6)
                    }

                    VStack(spacing: 4) {
                        Text("Update Available")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        // Gradient version pill
                        Text("Pointly \(newVersion)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(updateGradient)
                                    .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.4),
                                            radius: 6, x: 0, y: 2)
                            )
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, 18)

                // ── Divider ──────────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.8)
                    .padding(.horizontal, 20)

                // ── Body ─────────────────────────────────────────────────
                VStack(spacing: 16) {
                    Text("A new version is ready on the App Store\nwith fresh features and bug fixes.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Update button
                    Button(action: onUpdate) {
                        Text("Update Now")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(updateGradient)
                                    .shadow(
                                        color: (Color(hex: "#F4644D") ?? .orange)
                                            .opacity(hoverUpdate ? 0.70 : 0.45),
                                        radius: hoverUpdate ? 18 : 12, x: 0, y: 5
                                    )
                            )
                            .scaleEffect(hoverUpdate ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.14), value: hoverUpdate)
                    }
                    .buttonStyle(.plain)
                    .onHover { hoverUpdate = $0 }

                    // Later
                    Button(action: onDismiss) {
                        Text("Later")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(hoverLater ? 0.55 : 0.30))
                            .animation(.easeInOut(duration: 0.12), value: hoverLater)
                    }
                    .buttonStyle(.plain)
                    .onHover { hoverLater = $0 }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 290)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 10)
    }
}

// MARK: - Window presentation

private var updatePanel: NSPanel?

@MainActor
private func showUpdatePanel(storeVersion: String, storeURL: String) {
    updatePanel?.close()

    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 290, height: 400),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false          // SwiftUI draws its own shadow
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let view = UpdateCardView(
        newVersion: storeVersion,
        onUpdate: {
            if let url = URL(string: storeURL) { NSWorkspace.shared.open(url) }
            updatePanel?.close()
            updatePanel = nil
        },
        onDismiss: {
            updatePanel?.close()
            updatePanel = nil
        }
    )

    // Pad the hosting view by 40pt on each side so the shadow isn't clipped
    let pad: CGFloat = 40
    let hosting = NSHostingView(rootView: view.padding(pad))
    let fit = hosting.fittingSize
    hosting.frame = CGRect(origin: .zero, size: fit)
    panel.setContentSize(fit)
    panel.contentView?.addSubview(hosting)
    panel.center()
    panel.orderFrontRegardless()

    updatePanel = panel
}

// MARK: - Checker

final class UpdateChecker {

    static func checkOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            Task { await check() }
        }
    }

    @MainActor
    static func showPreview() {
        showUpdatePanel(
            storeVersion: "1.4",
            storeURL: "https://apps.apple.com/app/pointly/id6743359395"
        )
    }

    // MARK: - Private

    private static let bundleID          = "com.pointly.macos"
    private static let alertedVersionKey = "updateCheckerLastAlertedVersion"

    @MainActor
    private static func check() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else { return }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let storeVersion = first["version"] as? String,
              let storeURL = first["trackViewUrl"] as? String else { return }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard isNewer(storeVersion, than: currentVersion) else { return }

        let lastAlerted = UserDefaults.standard.string(forKey: alertedVersionKey) ?? ""
        guard lastAlerted != storeVersion else { return }

        showUpdatePanel(storeVersion: storeVersion, storeURL: storeURL)
        UserDefaults.standard.set(storeVersion, forKey: alertedVersionKey)
    }

    private static func isNewer(_ a: String, than b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }
}
