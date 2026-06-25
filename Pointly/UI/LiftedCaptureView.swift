import SwiftUI
import AppKit

struct LiftedCaptureView: View {
    let image: NSImage
    let onDismiss: () -> Void
    let onGetFrame: () -> NSRect       // snapshot current panel frame
    let onSetFrame: (NSRect) -> Void   // update panel frame

    @State private var isHovered   = false
    @State private var moveStart:   NSRect? = nil
    @State private var resizeStart: NSRect? = nil

    private enum HandlePos: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image body — drag to move the panel
            Image(nsImage: image)
                .resizable()
                .gesture(moveDrag)

            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.accentColor.opacity(0.9), lineWidth: 1.5)
                .allowsHitTesting(false)

            if isHovered {
                Button(action: onDismiss) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 20, height: 20)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity.animation(.easeInOut(duration: 0.12)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
        // Corner handles outside the clip so they render fully at the edges
        .overlay(alignment: .topLeading)     { if isHovered { handle(.topLeft) } }
        .overlay(alignment: .topTrailing)    { if isHovered { handle(.topRight) } }
        .overlay(alignment: .bottomLeading)  { if isHovered { handle(.bottomLeft) } }
        .overlay(alignment: .bottomTrailing) { if isHovered { handle(.bottomRight) } }
        .onHover { hovered in
            withAnimation { isHovered = hovered }
            (hovered ? NSCursor.openHand : NSCursor.arrow).set()
        }
    }

    // MARK: - Move (drag anywhere on the image body)

    private var moveDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard resizeStart == nil else { return }
                if moveStart == nil { moveStart = onGetFrame() }
                guard let sf = moveStart else { return }
                NSCursor.closedHand.set()
                onSetFrame(NSRect(
                    origin: NSPoint(x: sf.minX + value.translation.width,
                                   y: sf.minY - value.translation.height),
                    size: sf.size
                ))
            }
            .onEnded { _ in
                moveStart = nil
                NSCursor.openHand.set()
            }
    }

    // MARK: - Resize handle

    private func handle(_ pos: HandlePos) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: 11, height: 11)
            .contentShape(Circle().inset(by: -8))
            .onHover { hovered in (hovered ? NSCursor.crosshair : NSCursor.openHand).set() }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard moveStart == nil else { return }
                        if resizeStart == nil { resizeStart = onGetFrame() }
                        guard let sf = resizeStart else { return }
                        onSetFrame(resizedFrame(from: sf, handle: pos, delta: value.translation))
                    }
                    .onEnded { _ in resizeStart = nil }
            )
    }

    // MARK: - Frame math
    // AppKit origin is bottom-left of screen; SwiftUI drag dy > 0 means moving downward
    // on screen = decreasing y in AppKit, so vertical edges get -dy.

    private func resizedFrame(from s: NSRect, handle: HandlePos, delta: CGSize) -> NSRect {
        var minX = s.minX, maxX = s.maxX, minY = s.minY, maxY = s.maxY
        let dx = delta.width, dy = delta.height
        switch handle {
        case .topLeft:     minX += dx; maxY -= dy
        case .topRight:    maxX += dx; maxY -= dy
        case .bottomLeft:  minX += dx; minY -= dy
        case .bottomRight: maxX += dx; minY -= dy
        }
        if maxX - minX < 50 { maxX = minX + 50 }
        if maxY - minY < 50 { maxY = minY + 50 }
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
