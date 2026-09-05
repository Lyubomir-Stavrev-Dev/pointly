import SwiftUI
import AppKit

// MARK: - Shared State

final class MenuBarState: ObservableObject {
    static let shared = MenuBarState()
    @Published var isOverlayActive = false
    private init() {}
}

// MARK: - Widget Root

struct MenuBarWidgetView: View {
    @ObservedObject private var state = MenuBarState.shared
    @ObservedObject private var pro   = ProManager.shared

    var onToggleOverlay:      () -> Void
    var onCanvas:             () -> Void
    var onTimer:              () -> Void
    var onCues:               () -> Void
    var onZoom:               () -> Void
    var onSettings:           () -> Void
    var onKeyboardShortcuts:  () -> Void
    var onTutorial:           () -> Void
    var onQuit:               () -> Void

    private let gradient = LinearGradient(
        colors: [Color(hex: "#F4644D") ?? .orange, Color(hex: "#E9458C") ?? .pink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.08))
            VStack(spacing: 10) {
                toggleButton
                tilesGrid
            }
            .padding(12)
            Divider().overlay(Color.white.opacity(0.08))
            footer
        }
        .frame(width: 270)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(gradient)

            Text("Pointly")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            if pro.isPro {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(gradient.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(gradient.opacity(0.35), lineWidth: 0.5))
                    .foregroundStyle(gradient)
            } else {
                Button {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                } label: {
                    Text("✦ Go Pro")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(gradient.opacity(0.18)))
                        .overlay(Capsule().strokeBorder(gradient.opacity(0.30), lineWidth: 0.5))
                        .foregroundStyle(gradient)
                }
                .buttonStyle(.plain)
            }

            // Live status dot
            Circle()
                .fill(state.isOverlayActive
                      ? Color(hex: "#4CD964") ?? .green
                      : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
                .animation(.easeInOut(duration: 0.22), value: state.isOverlayActive)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Toggle

    private var toggleButton: some View {
        Button(action: onToggleOverlay) {
            HStack(spacing: 9) {
                Image(systemName: state.isOverlayActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(state.isOverlayActive ? "Stop Annotating" : "Start Annotating")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("⌘⇧P")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.38))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(state.isOverlayActive
                          ? AnyShapeStyle(Color.white.opacity(0.08))
                          : AnyShapeStyle(gradient))
                    .shadow(color: state.isOverlayActive
                            ? .clear
                            : (Color(hex: "#F4644D") ?? .orange).opacity(0.38),
                            radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(state.isOverlayActive ? Color.white.opacity(0.10) : .clear,
                                  lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: state.isOverlayActive)
    }

    // MARK: Tiles

    private var tilesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            WidgetTile(icon: "rectangle.on.rectangle", label: "Canvas", action: onCanvas)
            WidgetTile(icon: "timer",                   label: "Timer",  action: onTimer)
            WidgetTile(icon: "hand.raised",             label: "Cues",   action: onCues)
            WidgetTile(icon: "magnifyingglass",         label: "Zoom",   action: onZoom)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            HStack {
                FooterButton(label: "Shortcuts", icon: "keyboard",     action: onKeyboardShortcuts)
                Spacer()
                FooterButton(label: "Tutorial",  icon: "graduationcap", action: onTutorial)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider().overlay(Color.white.opacity(0.07))

            HStack {
                FooterButton(label: "Settings", icon: "gearshape", action: onSettings)
                Spacer()
                FooterButton(label: "Quit",     icon: "power",     action: onQuit, destructive: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Footer Button

private struct FooterButton: View {
    let label: String
    let icon: String
    let action: () -> Void
    var destructive: Bool = false
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 12))
                .foregroundColor(
                    hover
                        ? (destructive ? Color(hex: "#F4644D") ?? .orange : .white)
                        : .white.opacity(destructive ? 0.32 : 0.52)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hover ? Color.white.opacity(0.08) : .clear)
                )
                .animation(.easeInOut(duration: 0.12), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Tile

private struct WidgetTile: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(hover ? .white : .white.opacity(0.58))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(hover ? .white.opacity(0.80) : .white.opacity(0.36))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(hover ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(hover ? 0.15 : 0.07), lineWidth: 0.5)
                    )
            )
            .animation(.easeInOut(duration: 0.12), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
