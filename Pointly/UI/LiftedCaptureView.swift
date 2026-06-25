import SwiftUI
import AppKit

struct LiftedCaptureView: View {
    let image: NSImage
    let onDismiss: () -> Void
    let onResizeStart: () -> NSRect
    let onResize: (NSRect) -> Void

    @State private var isHovered = false
    @State private var startFrame: NSRect? = nil

    private enum HandlePos: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)

            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.accentColor.opacity(0.9), lineWidth: 1.5)

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
        // Corner handles sit outside the clip so they're fully visible
        .overlay(alignment: .topLeading)    { if isHovered { handle(.topLeft) } }
        .overlay(alignment: .topTrailing)   { if isHovered { handle(.topRight) } }
        .overlay(alignment: .bottomLeading) { if isHovered { handle(.bottomLeft) } }
        .overlay(alignment: .bottomTrailing){ if isHovered { handle(.bottomRight) } }
        .onHover { hovered in
            withAnimation { isHovered = hovered }
            (hovered ? NSCursor.openHand : NSCursor.arrow).set()
        }
    }

    private func handle(_ pos: HandlePos) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: 11, height: 11)
            .contentShape(Circle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startFrame == nil { startFrame = onResizeStart() }
                        guard let sf = startFrame else { return }
                        onResize(newFrame(from: sf, handle: pos, delta: value.translation))
                    }
                    .onEnded { _ in startFrame = nil }
            )
    }

    // Computes the updated NSRect (AppKit screen coords, origin bottom-left)
    // for a given corner drag. SwiftUI dy > 0 means downward on screen,
    // which is decreasing y in AppKit, so the signs are flipped for vertical edges.
    private func newFrame(from start: NSRect, handle: HandlePos, delta: CGSize) -> NSRect {
        var minX = start.minX, maxX = start.maxX
        var minY = start.minY, maxY = start.maxY
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
