import SwiftUI
import AppKit

struct LiftedCaptureView: View {
    let image: NSImage
    let onDismiss: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.accentColor.opacity(0.9), lineWidth: 1.5)
                )

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
        .onHover { hovered in
            withAnimation { isHovered = hovered }
            (hovered ? NSCursor.openHand : NSCursor.arrow).set()
        }
    }
}
