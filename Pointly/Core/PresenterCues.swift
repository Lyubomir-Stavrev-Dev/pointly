import AppKit
import SwiftUI
import Combine

// MARK: - Model

private struct ClickRipple: Identifiable {
    let id = UUID()
    let point: CGPoint      // in panel/view coords (top-left origin)
    let isRight: Bool
}

private struct KeyCap: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - Controller

/// Presenter cues: a click ripple + a keystroke pill overlay, driven by global
/// event monitors. Independent of draw/interact mode — it's a demo aid that
/// should work while the user drives any app. Requires Accessibility for the
/// global keystroke monitor (mouse monitor works without it).
final class PresenterCuesController: ObservableObject {
    @Published fileprivate var ripples: [ClickRipple] = []
    @Published fileprivate var keys: [KeyCap] = []
    @Published private(set) var isActive = false

    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var panel: NSPanel?
    private var keyClearWork: DispatchWorkItem?

    func toggle() {
        isActive ? stop() : start()
    }

    private func start() {
        guard !panel.exists else { return }

        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }

        let panel = NSPanel(contentRect: NSScreen.main?.frame ?? .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level                = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 4)
        panel.backgroundColor      = .clear
        panel.isOpaque             = false
        panel.hasShadow            = false
        panel.ignoresMouseEvents   = true   // pure overlay, never intercepts
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        if let screen = NSScreen.main { panel.setFrame(screen.frame, display: true) }
        panel.contentView = NSHostingView(rootView: PresenterCuesOverlay(controller: self))
        panel.orderFrontRegardless()
        self.panel = panel

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClick(event)
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
        }
        isActive = true
    }

    private func stop() {
        [mouseMonitor, keyMonitor, flagsMonitor].forEach { if let m = $0 { NSEvent.removeMonitor(m) } }
        mouseMonitor = nil; keyMonitor = nil; flagsMonitor = nil
        keyClearWork?.cancel(); keyClearWork = nil
        panel?.orderOut(nil)
        panel = nil
        ripples = []
        keys = []
        isActive = false
    }

    // NSEvent.mouseLocation is bottom-left screen coords; convert to the panel's
    // top-left view space on the screen that contains the click.
    private func handleClick(_ event: NSEvent) {
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(loc) }) ?? NSScreen.main,
              let panel else { return }
        if !screen.frame.equalTo(panel.frame) { panel.setFrame(screen.frame, display: true) }
        let viewPoint = CGPoint(x: loc.x - screen.frame.minX,
                                y: screen.frame.maxY - loc.y)   // flip to top-left
        let ripple = ClickRipple(point: viewPoint, isRight: event.type == .rightMouseDown)
        ripples.append(ripple)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.ripples.removeAll { $0.id == ripple.id }
        }
    }

    private func handleKey(_ event: NSEvent) {
        let combo = Self.describe(event)
        guard !combo.isEmpty else { return }
        keys.append(KeyCap(text: combo))
        if keys.count > 4 { keys.removeFirst(keys.count - 4) }
        keyClearWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.keys = [] }
        keyClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private static func describe(_ event: NSEvent) -> String {
        var parts: [String] = []
        let f = event.modifierFlags
        if f.contains(.control) { parts.append("⌃") }
        if f.contains(.option)  { parts.append("⌥") }
        if f.contains(.shift)   { parts.append("⇧") }
        if f.contains(.command) { parts.append("⌘") }
        let key = keyName(for: event)
        guard !key.isEmpty else { return "" }
        parts.append(key)
        return parts.joined()
    }

    private static func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36:  return "↩"
        case 48:  return "⇥"
        case 49:  return "Space"
        case 51:  return "⌫"
        case 53:  return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: break
        }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let c = chars.uppercased()
            // Printable, non-control characters only
            if c.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) { return c }
        }
        return ""
    }

    deinit { stop() }
}

private extension Optional where Wrapped == NSPanel {
    var exists: Bool { self != nil }
}

// MARK: - Overlay view

private struct PresenterCuesOverlay: View {
    @ObservedObject var controller: PresenterCuesController
    private let brand = Color(red: 0.96, green: 0.39, blue: 0.30)

    var body: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(controller.ripples) { ripple in
                    RippleView(color: ripple.isRight ? Color(red: 1, green: 0.55, blue: 0.26) : brand)
                        .position(ripple.point)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(controller.keys) { cap in
                            Text(cap.text)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.03, green: 0.03, blue: 0.07).opacity(0.9))
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(brand.opacity(0.6), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                                )
                                .transition(.scale(scale: 0.7).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 90)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: controller.keys.map(\.id))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RippleView: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2.5)
            .frame(width: 26, height: 26)
            .scaleEffect(animate ? 2.4 : 0.4)
            .opacity(animate ? 0 : 0.9)
            .overlay(
                Circle()
                    .fill(color.opacity(animate ? 0 : 0.35))
                    .frame(width: 26, height: 26)
                    .scaleEffect(animate ? 1.6 : 0.4)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.55)) { animate = true }
            }
    }
}
