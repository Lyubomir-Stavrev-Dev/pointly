import SwiftUI
import CoreGraphics
import Combine
import AppKit

// MARK: - Custom Text Field for Overlay Windows

/// A custom text field that works properly with overlay windows
struct OverlayTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let fontSize: Double
    let color: Color
    let onCommit: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.clear
        scrollView.drawsBackground = false
        
        // Configure text view for multiline support
        textView.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        textView.textColor = NSColor(color)
        textView.backgroundColor = NSColor.clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Remove default padding
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
        // Enable word wrapping and multiline
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        
        scrollView.documentView = textView
        
        print("🔍 OverlayTextField: Created multiline text view with placeholder: \(placeholder)")
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Update text if it changed externally
        if textView.string != text {
            textView.string = text
        }
        
        // Update font and color
        textView.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        textView.textColor = NSColor(color)
        
        // Focus text view when it's created and empty
        if text.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let window = nsView.window {
                    print("🔍 OverlayTextField: Attempting to focus text view")
                    window.makeKey()
                    let success = window.makeFirstResponder(textView)
                    print("🔍 OverlayTextField: Focus success: \(success)")
                    
                    // Prevent selecting all text on focus
                    let textLength = textView.string.count
                    textView.setSelectedRange(NSRange(location: textLength, length: 0))
                }
            }
        } else {
            // If text exists, place cursor at end (don't select all)
            let textLength = textView.string.count
            textView.setSelectedRange(NSRange(location: textLength, length: 0))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: OverlayTextField
        weak var textView: NSTextView?
        
        init(_ parent: OverlayTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = textView {
                print("🔍 OverlayTextField: Text changed to: '\(textView.string)'")
                parent.text = textView.string
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            // Handle selection changes if needed
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle special commands like Enter, Tab, etc.
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Allow Enter to create new line
                return false
            }
            return false
        }
    }
}

// MARK: - Shape Tool System for Pointly

/// Represents different types of shapes that can be drawn
enum ShapeType: String, CaseIterable, Identifiable {
    case rectangle = "rectangle"
    case ellipse = "ellipse"
    case arrow = "arrow"
    case line = "line"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .arrow: return "Arrow"
        case .line: return "Line"
        }
    }
    
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        }
    }
    
    var description: String {
        switch self {
        case .rectangle: return "Draw rectangular shapes"
        case .ellipse: return "Draw oval and circular shapes"
        case .arrow: return "Draw directional arrows"
        case .line: return "Draw straight lines"
        }
    }
    
    var color: Color {
        switch self {
        case .rectangle: return .blue
        case .ellipse: return .green
        case .arrow: return .orange
        case .line: return .purple
        }
    }
}

/// Represents a drawn shape with all its properties
struct DrawnShape: Identifiable, Equatable {
    let id = UUID()
    let type: ShapeType
    let startPoint: CGPoint
    let endPoint: CGPoint
    let color: Color
    let strokeWidth: CGFloat
    let isFilled: Bool
    let fillColor: Color?
    let timestamp: Date
    
    init(type: ShapeType, startPoint: CGPoint, endPoint: CGPoint, color: Color, strokeWidth: CGFloat = 3.0, isFilled: Bool = false, fillColor: Color? = nil) {
        self.type = type
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.strokeWidth = strokeWidth
        self.isFilled = isFilled
        self.fillColor = fillColor
        self.timestamp = Date()
    }
    
    /// Calculate the bounding rectangle for this shape
    var boundingRect: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Calculate the center point of the shape
    var center: CGPoint {
        CGPoint(x: (startPoint.x + endPoint.x) / 2, y: (startPoint.y + endPoint.y) / 2)
    }
    
    /// Calculate the width and height of the shape
    var size: CGSize {
        CGSize(width: abs(endPoint.x - startPoint.x), height: abs(endPoint.y - startPoint.y))
    }
}

/// Manages the state of shape drawing operations
class ShapeDrawingManager: ObservableObject {
    @Published var currentShapeType: ShapeType = .rectangle
    @Published var isDrawing = false
    @Published var currentShape: DrawnShape?
    @Published var drawnShapes: [DrawnShape] = []
    @Published var strokeWidth: CGFloat = 3.0
    @Published var strokeColor: Color = .blue
    @Published var isFilled: Bool = false
    @Published var fillColor: Color = .blue.opacity(0.3)
    
    /// Start drawing a new shape
    func startDrawing(at point: CGPoint, color: Color? = nil) {
        isDrawing = true
        currentShape = DrawnShape(
            type: currentShapeType,
            startPoint: point,
            endPoint: point,
            color: color ?? strokeColor,
            strokeWidth: strokeWidth,
            isFilled: isFilled,
            fillColor: isFilled ? fillColor : nil
        )
    }
    
    /// Update the current shape being drawn
    func updateDrawing(to point: CGPoint, color: Color? = nil) {
        guard isDrawing, var shape = currentShape else { return }
        shape = DrawnShape(
            type: shape.type,
            startPoint: shape.startPoint,
            endPoint: point,
            color: color ?? shape.color,
            strokeWidth: shape.strokeWidth,
            isFilled: shape.isFilled,
            fillColor: shape.fillColor
        )
        currentShape = shape
    }
    
    /// Finish drawing the current shape
    func finishDrawing() {
        guard isDrawing, let shape = currentShape else { return }
        drawnShapes.append(shape)
        currentShape = nil
        isDrawing = false
    }
    
    /// Cancel the current drawing operation
    func cancelDrawing() {
        currentShape = nil
        isDrawing = false
    }
    
    /// Clear all drawn shapes
    func clearAll() {
        drawnShapes.removeAll()
        currentShape = nil
        isDrawing = false
    }
    
    func updateShapePosition(_ shape: DrawnShape, to newPosition: CGPoint) {
        if let index = drawnShapes.firstIndex(where: { $0.id == shape.id }) {
            let currentShape = drawnShapes[index]
            let offset = CGPoint(
                x: newPosition.x - (currentShape.startPoint.x + currentShape.endPoint.x) / 2,
                y: newPosition.y - (currentShape.startPoint.y + currentShape.endPoint.y) / 2
            )
            
            drawnShapes[index] = DrawnShape(
                type: currentShape.type,
                startPoint: CGPoint(
                    x: currentShape.startPoint.x + offset.x,
                    y: currentShape.startPoint.y + offset.y
                ),
                endPoint: CGPoint(
                    x: currentShape.endPoint.x + offset.x,
                    y: currentShape.endPoint.y + offset.y
                ),
                color: currentShape.color,
                strokeWidth: currentShape.strokeWidth,
                isFilled: currentShape.isFilled,
                fillColor: currentShape.fillColor
            )
            print("🔍 ShapeDrawingManager: Updated shape position to \(newPosition)")
        }
    }
    
    /// Undo the last drawn shape
    func undoLast() {
        if !drawnShapes.isEmpty {
            drawnShapes.removeLast()
        }
    }
    
    /// Set the current shape type
    func setShapeType(_ type: ShapeType) {
        currentShapeType = type
    }
}

// MARK: - Shape Drawing Canvas

struct ShapeDrawingCanvas: View {
    @ObservedObject var shapeManager: ShapeDrawingManager
    var globalColor: Color? = nil
    @State private var dragStartPoint: CGPoint = .zero
    
    var body: some View {
        Canvas { context, size in
            // Draw all completed shapes
            for shape in shapeManager.drawnShapes {
                drawShape(shape, in: context)
            }
            
            // Draw the current shape being created
            if let currentShape = shapeManager.currentShape {
                drawShape(currentShape, in: context)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !shapeManager.isDrawing {
                        shapeManager.startDrawing(at: value.startLocation, color: globalColor)
                        dragStartPoint = value.startLocation
                    } else {
                        shapeManager.updateDrawing(to: value.location, color: globalColor)
                    }
                }
                .onEnded { _ in
                    shapeManager.finishDrawing()
                }
        )
        .onTapGesture { location in
            // For single-click shapes like points or small elements
            if shapeManager.currentShapeType == .line {
                shapeManager.startDrawing(at: location)
                shapeManager.finishDrawing()
            }
        }
    }
    
    private func drawShape(_ shape: DrawnShape, in context: GraphicsContext) {
        let rect = shape.boundingRect
        
        switch shape.type {
        case .rectangle:
            drawRectangle(shape, in: context, rect: rect)
        case .ellipse:
            drawEllipse(shape, in: context, rect: rect)
        case .arrow:
            drawArrow(shape, in: context, rect: rect)
        case .line:
            drawLine(shape, in: context)
        }
    }
    
    private func drawRectangle(_ shape: DrawnShape, in context: GraphicsContext, rect: CGRect) {
        let path = Path(roundedRect: rect, cornerRadius: 2)
        
        if shape.isFilled, let fillColor = shape.fillColor {
            context.fill(path, with: .color(fillColor))
        }
        
        context.stroke(
            path,
            with: .color(shape.color),
            style: StrokeStyle(lineWidth: shape.strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawEllipse(_ shape: DrawnShape, in context: GraphicsContext, rect: CGRect) {
        let path = Path(ellipseIn: rect)
        
        if shape.isFilled, let fillColor = shape.fillColor {
            context.fill(path, with: .color(fillColor))
        }
        
        context.stroke(
            path,
            with: .color(shape.color),
            style: StrokeStyle(lineWidth: shape.strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawArrow(_ shape: DrawnShape, in context: GraphicsContext, rect: CGRect) {
        let startPoint = shape.startPoint
        let endPoint = shape.endPoint
        
        // Calculate arrow direction and length
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let length = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Skip if arrow is too short
        guard length > 5 else { return }
        
        // Normalize direction vector
        let unitX = deltaX / length
        let unitY = deltaY / length
        
        // Arrow head size (proportional to stroke width)
        let headLength = max(shape.strokeWidth * 3, 15)
        let headWidth = max(shape.strokeWidth * 2, 10)
        
        // Calculate arrow head points
        let headPoint1 = CGPoint(
            x: endPoint.x - headLength * unitX + headWidth * unitY,
            y: endPoint.y - headLength * unitY - headWidth * unitX
        )
        let headPoint2 = CGPoint(
            x: endPoint.x - headLength * unitX - headWidth * unitY,
            y: endPoint.y - headLength * unitY + headWidth * unitX
        )
        
        // Create arrow path
        var arrowPath = Path()
        arrowPath.move(to: startPoint)
        arrowPath.addLine(to: endPoint)
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: headPoint1)
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: headPoint2)
        
        context.stroke(
            arrowPath,
            with: .color(shape.color),
            style: StrokeStyle(lineWidth: shape.strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawLine(_ shape: DrawnShape, in context: GraphicsContext) {
        var linePath = Path()
        linePath.move(to: shape.startPoint)
        linePath.addLine(to: shape.endPoint)
        
        context.stroke(
            linePath,
            with: .color(shape.color),
            style: StrokeStyle(lineWidth: shape.strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Shape Tool Palette

struct ShapeToolPalette: View {
    @ObservedObject var shapeManager: ShapeDrawingManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Shape type selector
            HStack(spacing: 12) {
                ForEach(ShapeType.allCases) { shapeType in
                    ShapeToolButton(
                        shapeType: shapeType,
                        isSelected: shapeManager.currentShapeType == shapeType,
                        action: {
                            shapeManager.setShapeType(shapeType)
                        }
                    )
                }
            }
            
            // Style controls
            HStack(spacing: 16) {
                // Stroke width slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stroke Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("1")
                            .font(.caption2)
                        Slider(value: $shapeManager.strokeWidth, in: 1...20, step: 1)
                        Text("20")
                            .font(.caption2)
                    }
                    .frame(width: 120)
                }
                
                // Color picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ColorPicker("", selection: $shapeManager.strokeColor)
                        .labelsHidden()
                        .frame(width: 30, height: 20)
                }
                
                // Fill toggle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("", isOn: $shapeManager.isFilled)
                        .labelsHidden()
                }
                
                // Fill color picker (only show if fill is enabled)
                if shapeManager.isFilled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fill Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ColorPicker("", selection: $shapeManager.fillColor)
                            .labelsHidden()
                            .frame(width: 30, height: 20)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Clear All") {
                    shapeManager.clearAll()
                }
                .buttonStyle(.bordered)
                .disabled(shapeManager.drawnShapes.isEmpty)
                
                Button("Undo") {
                    shapeManager.undoLast()
                }
                .buttonStyle(.bordered)
                .disabled(shapeManager.drawnShapes.isEmpty)
                
                Text("\(shapeManager.drawnShapes.count) shapes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ShapeToolButton: View {
    let shapeType: ShapeType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: shapeType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : shapeType.color)
                
                Text(shapeType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 70, height: 60)
            .background(
                isSelected ? shapeType.color : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(shapeType.color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Shape Preview Overlay

struct ShapePreviewOverlay: View {
    @ObservedObject var shapeManager: ShapeDrawingManager
    
    var body: some View {
        if shapeManager.isDrawing, let currentShape = shapeManager.currentShape {
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Drawing \(currentShape.type.displayName)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("Size: \(Int(currentShape.size.width)) × \(Int(currentShape.size.height))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Text Labels System

/// Text label structure for annotations
struct TextLabel: Identifiable, Equatable {
    var text: String
    var position: CGPoint
    var size: CGSize
    var fontSize: Double
    var color: Color
    var backgroundColor: Color?
    var isEditing: Bool = false
    var isSelected: Bool = false
    var alignment: LabelAlignment = .left
    var isBold: Bool = false
    var isItalic: Bool = false
    var id = UUID()
    
    // Computed properties
    var hasBackground: Bool {
        return backgroundColor != nil
    }
    
    var font: Font {
        var font = Font.system(size: fontSize, weight: isBold ? .bold : .regular)
        if isItalic {
            font = font.italic()
        }
        return font
    }
    
    static func == (lhs: TextLabel, rhs: TextLabel) -> Bool {
        return lhs.id == rhs.id
    }
}

enum LabelAlignment: String, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"
    
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        }
    }
    
    var icon: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
    
    var swiftUITextAlignment: TextAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

/// Text labels manager for handling text annotations
class TextLabelsManager: ObservableObject {
    @Published var textLabels: [TextLabel] = []
    @Published var fontSize: Double = 18.0
    @Published var textColor: Color = Color.primary
    @Published var backgroundColor: Color? = nil
    @Published var isEditing: Bool = false
    @Published var editingLabel: TextLabel?
    @Published var selectedLabel: TextLabel?
    @Published var alignment: LabelAlignment = .left
    @Published var isBold: Bool = false
    @Published var isItalic: Bool = false
    @Published var showBackground: Bool = false
    @Published var shouldCreateNewText: Bool = false
    
    func applyColorToSelectedLabels(_ color: Color) {
        textColor = color
        if let selected = selectedLabel, let idx = textLabels.firstIndex(where: { $0.id == selected.id }) {
            textLabels[idx].color = color
            selectedLabel = textLabels[idx]
        }
        if let editing = editingLabel, let idx = textLabels.firstIndex(where: { $0.id == editing.id }) {
            textLabels[idx].color = color
            editingLabel = textLabels[idx]
        }
    }
    
    func addLabel(at position: CGPoint, text: String = "", size: CGSize = CGSize(width: 300, height: 80)) {
        print("📝 TextLabelsManager: Adding label at \(position)")
        
        // First, finish editing any existing label
        if let currentEditing = editingLabel {
            if let index = textLabels.firstIndex(where: { $0.id == currentEditing.id }) {
                textLabels[index].isEditing = false
            }
        }
        
        // Deselect any selected label
        deselectAll()
        
        let newLabel = TextLabel(
            text: text,
            position: position,
            size: size,
            fontSize: fontSize,
            color: textColor,
            backgroundColor: showBackground ? backgroundColor : nil,
            isEditing: true,
            isSelected: false,
            alignment: alignment,
            isBold: isBold,
            isItalic: isItalic
        )
        textLabels.append(newLabel)
        editingLabel = newLabel
        selectedLabel = newLabel
        isEditing = true
        shouldCreateNewText = false // Don't create new text after this
        print("📝 TextLabelsManager: Label added with isEditing=true, total labels: \(textLabels.count)")
        print("📝 TextLabelsManager: editingLabel set to: \(editingLabel?.text ?? "nil")")
        
        // Focus the text field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = NSApplication.shared.keyWindow {
                window.makeKey()
            }
        }
    }
    
    func addLabelWithDrag(start: CGPoint, end: CGPoint) {
        let position = CGPoint(
            x: min(start.x, end.x),
            y: min(start.y, end.y)
        )
        let size = CGSize(
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        addLabel(at: position, text: "", size: size)
    }
    
    func updateLabel(_ label: TextLabel, with newText: String) {
        if let index = textLabels.firstIndex(where: { $0.id == label.id }) {
            textLabels[index].text = newText
            textLabels[index].fontSize = fontSize // Update to current fontSize
            textLabels[index].isEditing = false
            textLabels[index].isSelected = true // Make it selected after editing
            print("🔍 TextLabelsManager: Updated label '\(label.text)' to '\(newText)'")
        }
        editingLabel = nil
        isEditing = false
        selectedLabel = label // Set as selected label
        shouldCreateNewText = false // Don't create new text after editing
        print("📝 TextLabelsManager: Text editing finished, shouldCreateNewText = false, label selected")
    }
    
    func forceFinishEditing() {
        if isEditing {
            print("📝 TextLabelsManager: Force finishing text editing")
            isEditing = false
            editingLabel = nil
        }
    }
    
    func deleteLabel(_ label: TextLabel) {
        textLabels.removeAll { $0.id == label.id }
        if editingLabel?.id == label.id {
            editingLabel = nil
            isEditing = false
        }
    }
    
    func updateLabelPosition(_ label: TextLabel, to newPosition: CGPoint) {
        if let index = textLabels.firstIndex(where: { $0.id == label.id }) {
            textLabels[index].position = newPosition
        }
    }
    
    func updateLabelSize(_ label: TextLabel, to newSize: CGSize) {
        if let index = textLabels.firstIndex(where: { $0.id == label.id }) {
            // Ensure minimum size
            let minWidth: CGFloat = 60
            let minHeight: CGFloat = 30
            textLabels[index].size = CGSize(
                width: max(minWidth, newSize.width),
                height: max(minHeight, newSize.height)
            )
            print("📏 Updated label size to: \(textLabels[index].size)")
        }
    }
    
    func selectLabel(_ label: TextLabel) {
        deselectAll()
        if let index = textLabels.firstIndex(where: { $0.id == label.id }) {
            textLabels[index].isSelected = true
            selectedLabel = label
        }
    }
    
    func deselectAll() {
        for index in textLabels.indices {
            textLabels[index].isSelected = false
        }
        selectedLabel = nil
        isEditing = false
        editingLabel = nil
        print("📝 TextLabelsManager: Deselected all labels, cleared editing state")
    }
    
    func updateSelectedLabelFontSize(_ newSize: Double) {
        if let selected = selectedLabel, let index = textLabels.firstIndex(where: { $0.id == selected.id }) {
            textLabels[index].fontSize = newSize
        }
    }
    
    func updateSelectedLabelColor(_ newColor: Color) {
        if let selected = selectedLabel, let index = textLabels.firstIndex(where: { $0.id == selected.id }) {
            textLabels[index].color = newColor
        }
    }
    
    func updateSelectedLabelAlignment(_ newAlignment: LabelAlignment) {
        if let selected = selectedLabel, let index = textLabels.firstIndex(where: { $0.id == selected.id }) {
            textLabels[index].alignment = newAlignment
        }
    }
    
    func toggleSelectedLabelBold() {
        if let selected = selectedLabel, let index = textLabels.firstIndex(where: { $0.id == selected.id }) {
            textLabels[index].isBold.toggle()
        }
    }
    
    func toggleSelectedLabelItalic() {
        if let selected = selectedLabel, let index = textLabels.firstIndex(where: { $0.id == selected.id }) {
            textLabels[index].isItalic.toggle()
        }
    }
    
    func toggleSelectedLabelBackground() {
        if let selected = selectedLabel, let index = textLabels.firstIndex(where: { $0.id == selected.id }) {
            if textLabels[index].hasBackground {
                textLabels[index].backgroundColor = nil
            } else {
                textLabels[index].backgroundColor = backgroundColor
            }
        }
    }
    
    func clearAll() {
        textLabels.removeAll()
        editingLabel = nil
        selectedLabel = nil
        isEditing = false
        shouldCreateNewText = false // Don't create new text after clearing
    }
    
    func enableTextCreation() {
        // Only enable text creation if there are no existing labels
        shouldCreateNewText = textLabels.isEmpty
        print("📝 TextLabelsManager: Text creation enabled, shouldCreateNewText = \(shouldCreateNewText), textLabels count: \(textLabels.count)")
    }
}

/// Text formatting toolbar that appears when text is selected or editing
struct TextFormattingToolbar: View {
    @ObservedObject var textManager: TextLabelsManager
    @State private var showColorPicker = false
    
    // Get the active label (either selected or editing)
    private var activeLabel: TextLabel? {
        textManager.selectedLabel ?? textManager.editingLabel
    }
    
    var body: some View {
        if let selectedLabel = activeLabel {
            HStack(spacing: 12) {
                // Font size slider
                VStack {
                    Text("Size")
                        .font(.caption)
                        .foregroundColor(.white)
                    Slider(value: Binding(
                        get: { selectedLabel.fontSize },
                        set: { textManager.updateSelectedLabelFontSize($0) }
                    ), in: 10...72, step: 1)
                    .frame(width: 100)
                }
                
                // Color picker
                Button(action: { showColorPicker.toggle() }) {
                    Circle()
                        .fill(selectedLabel.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showColorPicker) {
                    ColorPicker("Text Color", selection: Binding(
                        get: { selectedLabel.color },
                        set: { textManager.updateSelectedLabelColor($0) }
                    ))
                    .padding()
                }
                
                // Alignment buttons
                HStack(spacing: 4) {
                    ForEach(LabelAlignment.allCases, id: \.self) { alignment in
                        Button(action: { textManager.updateSelectedLabelAlignment(alignment) }) {
                            Image(systemName: alignment.icon)
                                .foregroundColor(selectedLabel.alignment == alignment ? .blue : .white)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Bold/Italic toggles
                Button(action: { textManager.toggleSelectedLabelBold() }) {
                    Image(systemName: "bold")
                        .foregroundColor(selectedLabel.isBold ? .blue : .white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { textManager.toggleSelectedLabelItalic() }) {
                    Image(systemName: "italic")
                        .foregroundColor(selectedLabel.isItalic ? .blue : .white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Background toggle
                Button(action: { textManager.toggleSelectedLabelBackground() }) {
                    Image(systemName: selectedLabel.hasBackground ? "rectangle.fill" : "rectangle")
                        .foregroundColor(selectedLabel.hasBackground ? .blue : .white)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

/// Canvas for rendering text labels
struct TextLabelsCanvas: View {
    @ObservedObject var textManager: TextLabelsManager
    @State private var editingText: String = ""
    
    var body: some View {
        ZStack {
            ForEach(textManager.textLabels) { label in
                TextLabelView(
                    label: label,
                    textManager: textManager,
                    editingText: $editingText
                )
                // Allow hit testing for resize handles, but not for the text itself
                .allowsHitTesting(label.isEditing || label.isSelected) // Enable for editing/selected labels to show resize handles
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        // Allow hit testing so resize handles can be dragged
        .allowsHitTesting(true)
        .onAppear {
            // Sync editing text when a new label is added
            if let editingLabel = textManager.editingLabel {
                editingText = editingLabel.text
            }
        }
        .onChange(of: textManager.editingLabel) { newLabel in
            if let newLabel = newLabel {
                editingText = newLabel.text
            }
        }
    }
}

/// Individual text label view with comprehensive features
struct TextLabelView: View {
    let label: TextLabel
    @ObservedObject var textManager: TextLabelsManager
    @Binding var editingText: String
    @State private var isHovered = false
    @State private var localText: String = ""
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var resizeOffset: CGSize = .zero
    @State private var isResizing = false
    
    var body: some View {
        if label.isEditing {
            // Editing mode - use custom text field with resize handles
            let currentLabel = textManager.textLabels.first(where: { $0.id == label.id }) ?? label
            let currentSize = currentLabel.size
            let currentPosition = currentLabel.position
            let handlePosition = CGPoint(x: currentPosition.x + currentSize.width/2, y: currentPosition.y + currentSize.height/2)
            
            ZStack {
                // Active bounding box for clarity
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .frame(width: currentSize.width, height: currentSize.height)
                    .position(currentPosition)
                    .zIndex(1000)
                
                // Text field
                OverlayTextField(
                    text: $localText,
                    placeholder: "Type here...",
                    fontSize: textManager.fontSize,
                    color: label.color,
                    onCommit: {
                        textManager.updateLabel(label, with: localText)
                    }
                )
                .frame(width: currentSize.width, height: currentSize.height)
                .position(currentPosition)
                .allowsHitTesting(true)
                
                // Resize handle inside editing view (always visible while editing)
                resizeHandleView(at: handlePosition, size: currentSize)
            }
            .onAppear {
                localText = label.text
                textManager.editingLabel = label
                textManager.isEditing = true
                textManager.selectedLabel = label
                print("🔍 TextLabelView: Entering editing mode for label: \(label.text)")
            }
            .onDisappear {
                if textManager.editingLabel?.id == label.id {
                    textManager.editingLabel = nil
                    textManager.isEditing = false
                }
            }
            .onChange(of: textManager.fontSize) { newSize in
                // Update label fontSize when manager fontSize changes (for currently editing label)
                if label.isEditing, let index = textManager.textLabels.firstIndex(where: { $0.id == label.id }) {
                    textManager.textLabels[index].fontSize = newSize
                }
            }
        } else {
            // Display mode - show text with selection and resize handles
            ZStack {
                // Text content
                Text(label.text.isEmpty ? "Type here..." : label.text)
                    .font(label.font)
                    .foregroundColor(label.text.isEmpty ? Color.gray : Color.white.opacity(0.8))
                    .multilineTextAlignment(label.alignment.swiftUITextAlignment)
                    .frame(width: label.size.width, height: label.size.height, alignment: textAlignment)
                    .background(
                        label.hasBackground ? 
                        RoundedRectangle(cornerRadius: 4)
                            .fill(label.backgroundColor ?? Color.clear)
                        : nil
                    )
                    .position(
                        x: label.position.x + dragOffset.width,
                        y: label.position.y + dragOffset.height
                    )
                
                // Selection bounding box
                if label.isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .frame(width: label.size.width, height: label.size.height)
                        .position(
                            x: label.position.x + dragOffset.width,
                            y: label.position.y + dragOffset.height
                        )
                    
                    // Selection corner handles (visual only - for dragging use main overlay)
                    ForEach(["top-left", "top-right", "bottom-left", "bottom-right"], id: \.self) { corner in
                        let offset = cornerOffset(for: corner, size: label.size)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            .position(
                                x: label.position.x + dragOffset.width + offset.x,
                                y: label.position.y + dragOffset.height + offset.y
                            )
                    }
                }
                
                // Resize handle visible when selected or active
                let isActive = label.isSelected || textManager.selectedLabel?.id == label.id || textManager.editingLabel?.id == label.id
                if isActive {
                    let handlePosition = CGPoint(
                        x: label.position.x + dragOffset.width + label.size.width/2,
                        y: label.position.y + dragOffset.height + label.size.height/2
                    )
                    resizeHandleView(at: handlePosition, size: label.size)
                }
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .opacity(isDragging ? 0.8 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            // All gestures removed - main overlay handles all interactions
            .contextMenu {
                Button("Edit") {
                    textManager.editingLabel = label
                    textManager.isEditing = true
                    localText = label.text
                }
                Button("Delete", role: .destructive) {
                    textManager.deleteLabel(label)
                }
            }
        }
    }
    
    @ViewBuilder
    private func resizeHandleView(at position: CGPoint, size: CGSize) -> some View {
        // Very visible handle with glow
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.75))
                .frame(width: 54, height: 54)
            Circle()
                .fill(Color.white)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(Color.blue, lineWidth: 5))
                .overlay(
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                )
        }
        .shadow(color: .black.opacity(0.7), radius: 8)
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newWidth = max(60, size.width + value.translation.width)
                    let newHeight = max(30, size.height + value.translation.height)
                    textManager.updateLabelSize(label, to: CGSize(width: newWidth, height: newHeight))
                }
        )
        .allowsHitTesting(true)
        .zIndex(2_000_000)
        .compositingGroup()
    }
    
    private var textAlignment: Alignment {
        switch label.alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
    
    private func cornerOffset(for corner: String, size: CGSize) -> CGPoint {
        switch corner {
        case "top-left": return CGPoint(x: -size.width/2, y: -size.height/2)
        case "top-right": return CGPoint(x: size.width/2, y: -size.height/2)
        case "bottom-left": return CGPoint(x: -size.width/2, y: size.height/2)
        case "bottom-right": return CGPoint(x: size.width/2, y: size.height/2)
        default: return .zero
        }
    }
    
}

// MARK: - Resize Handle View
struct ResizeHandleView: View {
    let position: String
    let labelPosition: CGPoint
    let labelSize: CGSize
    let onResize: (CGSize) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        let handleOffset = getHandleOffset()
        let handlePosition = CGPoint(
            x: labelPosition.x + handleOffset.x,
            y: labelPosition.y + handleOffset.y
        )
        
        // Resize handle icon - make it VERY visible with bright colors
        ZStack {
            // Large outer glow - bright and visible
            Circle()
                .fill(Color.yellow.opacity(0.5))
                .frame(width: 50, height: 50)
            
            // Medium glow
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 40, height: 40)
            
            // Main handle - larger and more prominent
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 4)
                )
                .overlay(
                    Image(systemName: getHandleIcon())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                )
        }
        .position(
            x: handlePosition.x + dragOffset.width,
            y: handlePosition.y + dragOffset.height
        )
        .allowsHitTesting(true)
        .zIndex(99999) // Very high z-index to ensure it's on top
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    dragOffset = value.translation
                    
                    // Calculate new size based on drag
                    let newSize = calculateNewSize(translation: value.translation)
                    onResize(newSize)
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                }
        )
    }
    
    private func getHandleOffset() -> CGPoint {
        switch position {
        case "top-left":
            return CGPoint(x: -labelSize.width/2, y: -labelSize.height/2)
        case "top-right":
            return CGPoint(x: labelSize.width/2, y: -labelSize.height/2)
        case "bottom-left":
            return CGPoint(x: -labelSize.width/2, y: labelSize.height/2)
        case "bottom-right":
            return CGPoint(x: labelSize.width/2, y: labelSize.height/2)
        case "top":
            return CGPoint(x: 0, y: -labelSize.height/2)
        case "bottom":
            return CGPoint(x: 0, y: labelSize.height/2)
        case "left":
            return CGPoint(x: -labelSize.width/2, y: 0)
        case "right":
            return CGPoint(x: labelSize.width/2, y: 0)
        default:
            return .zero
        }
    }
    
    private func getHandleIcon() -> String {
        switch position {
        case "top-left", "bottom-right":
            return "arrow.up.left.and.arrow.down.right"
        case "top-right", "bottom-left":
            return "arrow.up.right.and.arrow.down.left"
        case "top", "bottom":
            return "arrow.up.and.down"
        case "left", "right":
            return "arrow.left.and.right"
        default:
            return "arrow.up.left.and.arrow.down.right"
        }
    }
    
    private func calculateNewSize(translation: CGSize) -> CGSize {
        let minWidth: CGFloat = 50
        let minHeight: CGFloat = 20
        
        var newWidth = labelSize.width
        var newHeight = labelSize.height
        
        switch position {
        case "top-left":
            newWidth = max(minWidth, labelSize.width - translation.width)
            newHeight = max(minHeight, labelSize.height - translation.height)
        case "top-right":
            newWidth = max(minWidth, labelSize.width + translation.width)
            newHeight = max(minHeight, labelSize.height - translation.height)
        case "bottom-left":
            newWidth = max(minWidth, labelSize.width - translation.width)
            newHeight = max(minHeight, labelSize.height + translation.height)
        case "bottom-right":
            newWidth = max(minWidth, labelSize.width + translation.width)
            newHeight = max(minHeight, labelSize.height + translation.height)
        case "top":
            newHeight = max(minHeight, labelSize.height - translation.height)
        case "bottom":
            newHeight = max(minHeight, labelSize.height + translation.height)
        case "left":
            newWidth = max(minWidth, labelSize.width - translation.width)
        case "right":
            newWidth = max(minWidth, labelSize.width + translation.width)
        default:
            break
        }
        
        return CGSize(width: newWidth, height: newHeight)
    }
}
