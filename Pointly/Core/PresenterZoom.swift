import AppKit
import SwiftUI
import ScreenCaptureKit

/// ZoomIt-style presenter zoom: freezes the screen (SCK snapshot) and lets the
/// user zoom toward the cursor with scroll/±, pan by moving the mouse, and exit
/// with Esc or click. A takeover panel (not click-through) owns input while live.
final class PresenterZoomController: ObservableObject {
    @Published fileprivate var image: NSImage?
    @Published fileprivate var scale: CGFloat = 1
    @Published fileprivate var anchor: CGPoint = .zero   // focus point in view coords
    @Published private(set) var isActive = false

    private var panel: NSPanel?
    private var monitor: Any?
    private var screenFrame: NSRect = .zero

    func toggle() {
        if isActive { stop() } else { Task { await start() } }
    }

    private func start() async {
        // Read screen geometry on main and carry only value types across the
        // await (NSScreen isn't Sendable).
        let geo: (frame: NSRect, scale: CGFloat)? = await MainActor.run {
            guard !isActive, let s = NSScreen.main else { return nil }
            return (s.frame, s.backingScaleFactor)
        }
        guard let geo else { return }
        let frame = geo.frame

        guard let content = try? await SCShareableContent.current,
              let display = content.displays.first(where: {
                  $0.frame.intersects(frame)
              }) ?? content.displays.first else { return }

        let ourPID = pid_t(ProcessInfo.processInfo.processIdentifier)
        let excluded = content.windows.filter { $0.owningApplication?.processID == ourPID }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let cfg = SCStreamConfiguration()
        cfg.width  = Int(frame.width * geo.scale)
        cfg.height = Int(frame.height * geo.scale)
        cfg.showsCursor = true
        guard let cg = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: cfg) else { return }

        await MainActor.run {
            screenFrame = frame
            image = NSImage(cgImage: cg, size: frame.size)
            scale = 1
            anchor = CGPoint(x: frame.width / 2, y: frame.height / 2)
            presentPanel()
            isActive = true
        }
    }

    private func presentPanel() {
        let panel = NSPanel(contentRect: screenFrame,
                            styleMask: [.borderless],
                            backing: .buffered, defer: false)
        panel.level              = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 5)
        panel.backgroundColor    = .black
        panel.isOpaque           = true
        panel.hasShadow          = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = FirstMouseHostingView(rootView: PresenterZoomView(controller: self))
        panel.setFrame(screenFrame, display: true)
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor: scroll to zoom, move to pan, Esc/click to exit.
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel, .mouseMoved, .leftMouseDown, .keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// Returns true if the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            switch event.keyCode {
            case 53, 49: stop(); return true                 // Esc / Space exits
            case 24, 69: zoom(by: 1.15); return true         // = / +
            case 27, 78: zoom(by: 1 / 1.15); return true     // - / _
            default: return true                              // swallow other keys while zoomed
            }
        case .leftMouseDown:
            stop(); return true
        case .scrollWheel:
            let factor = 1 + (event.scrollingDeltaY / 300)
            zoom(by: factor)
            return true
        case .mouseMoved:
            updateAnchorFromCursor()
            return true
        default:
            return false
        }
    }

    private func zoom(by factor: CGFloat) {
        updateAnchorFromCursor()
        scale = min(8, max(1, scale * factor))
    }

    private func updateAnchorFromCursor() {
        let loc = NSEvent.mouseLocation
        anchor = CGPoint(x: loc.x - screenFrame.minX,
                         y: screenFrame.maxY - loc.y)   // flip to top-left view space
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        panel?.orderOut(nil)
        panel = nil
        image = nil
        isActive = false
    }
}

// MARK: - View

private struct PresenterZoomView: View {
    @ObservedObject var controller: PresenterZoomController

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black
                if let image = controller.image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: geo.size.width, height: geo.size.height)
                        // Scale about the cursor anchor: translate anchor to
                        // origin, scale, translate back.
                        .scaleEffect(controller.scale, anchor: .topLeading)
                        .offset(x: -controller.anchor.x * (controller.scale - 1),
                                y: -controller.anchor.y * (controller.scale - 1))
                        .animation(.easeOut(duration: 0.12), value: controller.scale)
                        .animation(.easeOut(duration: 0.08), value: controller.anchor)
                }

                VStack {
                    Spacer()
                    Text("Scroll to zoom · move to pan · Esc to exit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)
                        .opacity(controller.scale > 1.02 ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: controller.scale)
                }
            }
        }
        .ignoresSafeArea()
    }
}
