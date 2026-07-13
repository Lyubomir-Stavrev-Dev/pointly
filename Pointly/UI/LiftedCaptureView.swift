import SwiftUI
import AppKit

struct LiftedCaptureView: View {
    let image: NSImage
    let onDismiss: () -> Void
    let onGetFrame: () -> NSRect
    let onSetFrame: (NSRect) -> Void

    @State private var isHovered = false

    // Move: snapshot cursor + panel origin at drag start
    @State private var moveInitialCursor: NSPoint? = nil
    @State private var moveInitialOrigin: NSPoint? = nil

    // Resize: snapshot cursor + panel frame at drag start
    @State private var resizeInitialCursor: NSPoint? = nil
    @State private var resizeInitialFrame:  NSRect?  = nil

    private enum HandlePos: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
        .overlay(alignment: .topLeading)     { if isHovered { handle(.topLeft) } }
        .overlay(alignment: .topTrailing)    { if isHovered { handle(.topRight) } }
        .overlay(alignment: .bottomLeading)  { if isHovered { handle(.bottomLeft) } }
        .overlay(alignment: .bottomTrailing) { if isHovered { handle(.bottomRight) } }
        .onHover { hovered in
            withAnimation { isHovered = hovered }
            // Only set the hand on entry — forcing .arrow on exit stomped the
            // custom tool cursor when the pointer moved back onto the canvas
            // (the canvas's onContinuousHover restores it anyway).
            if hovered { NSCursor.openHand.set() }
        }
    }

    // MARK: - Move
    // Uses NSEvent.mouseLocation (AppKit screen coords) so the computation is
    // completely independent of the SwiftUI view's coordinate space, which shifts
    // as the panel moves and would otherwise cause jumps in value.translation.

    private var moveDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard resizeInitialCursor == nil else { return }
                if moveInitialCursor == nil {
                    moveInitialCursor = NSEvent.mouseLocation
                    moveInitialOrigin = onGetFrame().origin
                }
                guard let ic = moveInitialCursor, let io = moveInitialOrigin else { return }
                let cur = NSEvent.mouseLocation
                NSCursor.closedHand.set()
                onSetFrame(NSRect(
                    origin: NSPoint(x: io.x + cur.x - ic.x, y: io.y + cur.y - ic.y),
                    size: onGetFrame().size
                ))
            }
            .onEnded { _ in
                moveInitialCursor = nil
                moveInitialOrigin = nil
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
                    .onChanged { _ in
                        guard moveInitialCursor == nil else { return }
                        if resizeInitialCursor == nil {
                            resizeInitialCursor = NSEvent.mouseLocation
                            resizeInitialFrame  = onGetFrame()
                        }
                        guard let ic = resizeInitialCursor,
                              let sf = resizeInitialFrame else { return }
                        let cur = NSEvent.mouseLocation
                        let dx  = cur.x - ic.x
                        let dy  = cur.y - ic.y
                        onSetFrame(resizedFrame(sf, pos, dx, dy))
                    }
                    .onEnded { _ in
                        resizeInitialCursor = nil
                        resizeInitialFrame  = nil
                    }
            )
    }

    private func resizedFrame(_ s: NSRect, _ h: HandlePos, _ dx: CGFloat, _ dy: CGFloat) -> NSRect {
        var minX = s.minX, maxX = s.maxX, minY = s.minY, maxY = s.maxY
        switch h {
        case .topLeft:     minX += dx; maxY += dy
        case .topRight:    maxX += dx; maxY += dy
        case .bottomLeft:  minX += dx; minY += dy
        case .bottomRight: maxX += dx; minY += dy
        }
        if maxX - minX < 50 { maxX = minX + 50 }
        if maxY - minY < 50 { maxY = minY + 50 }
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
