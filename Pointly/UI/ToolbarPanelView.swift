import SwiftUI

/// Hosts the toolbar pill and the adaptive size bar side by side.
/// Reports the combined size so OverlayWindowManager keeps the panel frame tight.
struct ToolbarPanelView: View {
    @ObservedObject var drawingState: DrawingState
    @ObservedObject var interactionMode: InteractionModeManager
    var onSizeChange: ((CGSize) -> Void)?

    @State private var toolbarHeight: CGFloat = 360

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            FloatingToolbar(drawingState: drawingState, interactionMode: interactionMode)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear    { toolbarHeight = geo.size.height }
                            .onChange(of: geo.size) { toolbarHeight = $0.height }
                    }
                )

            SizeBar(drawingState: drawingState)
                .frame(height: toolbarHeight)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toolbarHeight)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear    { onSizeChange?(geo.size) }
                    .onChange(of: geo.size) { onSizeChange?($0) }
            }
        )
        .fixedSize()
    }
}
