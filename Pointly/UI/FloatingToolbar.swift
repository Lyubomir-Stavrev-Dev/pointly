import SwiftUI

/// Floating toolbar with annotation tools
/// 
/// **Phase 2.1 Enhancement**: Added interaction mode integration and new professional tools
struct FloatingToolbar: View {
    @ObservedObject var drawingState: DrawingState
    @Binding var position: CGPoint
    @State private var isDragging = false
    @State private var showExportMenu = false
    @StateObject private var exportManager = ExportManager()
    @StateObject private var interactionMode = InteractionModeManager()
    
    private let toolbarWidth: CGFloat = 500
    private let toolbarHeight: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 8) {
            // Interaction Mode Toggle (Top Row)
            HStack {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { interactionMode.toggleMode() }) {
                    HStack(spacing: 4) {
                        Image(systemName: interactionMode.currentMode.systemImage)
                            .font(.system(size: 14))
                        Text(interactionMode.currentMode.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(interactionMode.currentMode == .draw ? Color.accentColor : Color.secondary.opacity(0.2))
                    )
                    .foregroundColor(interactionMode.currentMode == .draw ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Quick mode indicator
                if interactionMode.isTransitioning {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            
            // Tools Row
            HStack(spacing: 8) {
                // Core Tools
                toolButton(.pen, isSelected: drawingState.selectedTool == .pen)
                toolButton(.highlighter, isSelected: drawingState.selectedTool == .highlighter)
                toolButton(.eraser, isSelected: drawingState.selectedTool == .eraser)
                
                Divider()
                    .frame(height: 25)
                
                // Professional Tools (Phase 2.1)
                toolButton(.marker, isSelected: drawingState.selectedTool == .marker)
                toolButton(.blurBrush, isSelected: drawingState.selectedTool == .blurBrush)
                toolButton(.laserPointer, isSelected: drawingState.selectedTool == .laserPointer)
                
                Divider()
                    .frame(height: 25)
            
                // Shape tools
                toolButton(.rectangle, isSelected: drawingState.selectedTool == .rectangle)
                toolButton(.ellipse, isSelected: drawingState.selectedTool == .ellipse)
                toolButton(.arrow, isSelected: drawingState.selectedTool == .arrow)
                toolButton(.line, isSelected: drawingState.selectedTool == .line)
                
                Divider()
                    .frame(height: 25)
                
                // Text tool
                toolButton(.text, isSelected: drawingState.selectedTool == .text)
                
                Divider()
                    .frame(height: 25)
            
                // Undo/Redo
                Button(action: { drawingState.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                        .foregroundColor(drawingState.canUndo ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .disabled(!drawingState.canUndo)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { drawingState.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                        .foregroundColor(drawingState.canRedo ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .disabled(!drawingState.canRedo)
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .frame(height: 25)
                
                // Color picker
                ColorPicker("", selection: $drawingState.selectedColor)
                    .frame(width: 28, height: 28)
                    .disabled(!drawingState.selectedTool.supportsColor)
                
                // Thickness slider (only for supported tools)
                if drawingState.selectedTool.supportsThickness {
                    VStack(spacing: 2) {
                        Text("\(Int(drawingState.strokeThickness))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(value: $drawingState.strokeThickness, in: 1...10, step: 1)
                            .frame(width: 50)
                    }
                }

                // Fill toggle for shape tools
                if drawingState.selectedTool == .rectangle || drawingState.selectedTool == .ellipse {
                    Button(action: { drawingState.isFilled.toggle() }) {
                        Image(systemName: drawingState.isFilled ? "square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(drawingState.isFilled ? .accentColor : .primary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle fill")
                }

                Divider()
                    .frame(height: 25)
            
            // Export menu
            Menu {
                Button("Export as PNG") {
                    exportManager.showExportPanel(
                        for: drawingState,
                        format: .png,
                        size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
                    )
                }
                Button("Export as PDF") {
                    exportManager.showExportPanel(
                        for: drawingState,
                        format: .pdf,
                        size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
                    )
                }
                Button("Export as JPEG") {
                    exportManager.showExportPanel(
                        for: drawingState,
                        format: .jpeg,
                        size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
                    )
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
                // Clear all button
                Button(action: { drawingState.clearAll() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
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
        .onAppear {
            // Ensure toolbar stays within screen bounds
            constrainToScreen()
        }
    }
    
    private func toolButton(_ tool: DrawingTool, isSelected: Bool) -> some View {
        Button(action: { 
            drawingState.selectedTool = tool
            // Provide haptic feedback for tool selection
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }) {
            VStack(spacing: 2) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Tool name for new professional tools
                if [.marker, .blurBrush, .laserPointer].contains(tool) {
                    Text(tool.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 32, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                            .opacity(isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(tool.description)  // Tooltip with tool description
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
                constrainToScreen()
            }
            .onEnded { _ in
                isDragging = false
            }
    }
    
    /// Constrain toolbar position to screen bounds
    private func constrainToScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let minX = screenFrame.minX + toolbarWidth / 2
        let maxX = screenFrame.maxX - toolbarWidth / 2
        let minY = screenFrame.minY + toolbarHeight / 2
        let maxY = screenFrame.maxY - toolbarHeight / 2
        
        position.x = max(minX, min(maxX, position.x))
        position.y = max(minY, min(maxY, position.y))
    }
}

#Preview {
    FloatingToolbar(
        drawingState: DrawingState(),
        position: .constant(CGPoint(x: 150, y: 100))
    )
    .frame(width: 400, height: 200)
}
