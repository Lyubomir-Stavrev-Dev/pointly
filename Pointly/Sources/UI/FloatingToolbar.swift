import SwiftUI

/// Floating toolbar with annotation tools
struct FloatingToolbar: View {
    @ObservedObject var drawingState: DrawingState
    @Binding var position: CGPoint
    @State private var isDragging = false
    
    private let toolbarWidth: CGFloat = 300
    private let toolbarHeight: CGFloat = 60
    
    var body: some View {
        HStack(spacing: 12) {
            // Tool selection buttons
            toolButton(.pen, icon: "pencil", isSelected: drawingState.selectedTool == .pen)
            toolButton(.highlighter, icon: "highlighter", isSelected: drawingState.selectedTool == .highlighter)
            toolButton(.eraser, icon: "eraser", isSelected: drawingState.selectedTool == .eraser)
            
            Divider()
                .frame(height: 30)
            
            // Shape tools
            toolButton(.rectangle, icon: "rectangle", isSelected: drawingState.selectedTool == .rectangle)
            toolButton(.ellipse, icon: "ellipse", isSelected: drawingState.selectedTool == .ellipse)
            toolButton(.arrow, icon: "arrow.right", isSelected: drawingState.selectedTool == .arrow)
            toolButton(.line, icon: "line.diagonal", isSelected: drawingState.selectedTool == .line)
            
            Divider()
                .frame(height: 30)
            
            // Text tool
            toolButton(.text, icon: "textformat", isSelected: drawingState.selectedTool == .text)
            
            Divider()
                .frame(height: 30)
            
            // Undo/Redo
            Button(action: { drawingState.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundColor(drawingState.canUndo ? .primary : .secondary)
            }
            .disabled(!drawingState.canUndo)
            
            Button(action: { drawingState.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .foregroundColor(drawingState.canRedo ? .primary : .secondary)
            }
            .disabled(!drawingState.canRedo)
            
            Divider()
                .frame(height: 30)
            
            // Color picker
            ColorPicker("", selection: $drawingState.selectedColor)
                .frame(width: 30, height: 30)
            
            // Thickness slider
            Slider(value: $drawingState.strokeThickness, in: 1...10, step: 1)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
        .frame(width: toolbarWidth, height: toolbarHeight)
        .gesture(dragGesture)
    }
    
    private func toolButton(_ tool: DrawingTool, icon: String, isSelected: Bool) -> some View {
        Button(action: { drawingState.selectedTool = tool }) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                }
                let newX = position.x + value.translation.x
                let newY = position.y + value.translation.y
                position = CGPoint(x: newX, y: newY)
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

#Preview {
    FloatingToolbar(
        drawingState: DrawingState(),
        position: .constant(CGPoint(x: 150, y: 100))
    )
    .frame(width: 400, height: 200)
}
