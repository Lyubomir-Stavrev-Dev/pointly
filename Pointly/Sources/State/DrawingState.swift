import SwiftUI
import Combine

/// Drawing tools available in the toolbar
enum DrawingTool: CaseIterable {
    case pen
    case highlighter
    case eraser
    case rectangle
    case ellipse
    case arrow
    case line
    case text
}

/// Represents a single drawing stroke or shape
struct DrawingElement: Identifiable {
    let id = UUID()
    let tool: DrawingTool
    let points: [CGPoint]
    let color: Color
    let thickness: CGFloat
    let opacity: Double
    let timestamp: Date
    
    init(tool: DrawingTool, points: [CGPoint], color: Color, thickness: CGFloat) {
        self.tool = tool
        self.points = points
        self.color = color
        self.thickness = thickness
        self.opacity = tool == .highlighter ? 0.4 : 1.0
        self.timestamp = Date()
    }
}

/// Main state manager for drawing operations
class DrawingState: ObservableObject {
    // Published properties for UI binding
    @Published var selectedTool: DrawingTool = .pen
    @Published var selectedColor: Color = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
    @Published var strokeThickness: CGFloat = 3.0
    
    // Drawing elements and undo/redo stacks
    @Published private(set) var elements: [DrawingElement] = []
    private var undoStack: [[DrawingElement]] = []
    private var redoStack: [[DrawingElement]] = []
    
    // Current drawing state
    private var currentStroke: [CGPoint] = []
    private var isDrawing = false
    
    // Computed properties for undo/redo availability
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    init() {
        // Initialize with default state
        saveStateForUndo()
    }
    
    // MARK: - Drawing Operations
    
    func startDrawing(at point: CGPoint) {
        guard !isDrawing else { return }
        saveStateForUndo()
        currentStroke = [point]
        isDrawing = true
    }
    
    func continueDrawing(to point: CGPoint) {
        guard isDrawing else { return }
        currentStroke.append(point)
        updateCurrentElement()
    }
    
    func addPoint(_ point: CGPoint, for tool: DrawingTool) {
        if !isDrawing {
            startNewStroke(at: point, tool: tool)
        } else {
            continueStroke(to: point)
        }
    }
    
    private func startNewStroke(at point: CGPoint, tool: DrawingTool) {
        saveStateForUndo()
        currentStroke = [point]
        isDrawing = true
        selectedTool = tool
    }
    
    private func continueStroke(to point: CGPoint) {
        currentStroke.append(point)
        updateCurrentElement()
    }
    
    func finishStroke() {
        guard isDrawing && !currentStroke.isEmpty else { return }
        
        let element = DrawingElement(
            tool: selectedTool,
            points: currentStroke,
            color: selectedColor,
            thickness: strokeThickness
        )
        
        elements.append(element)
        currentStroke.removeAll()
        isDrawing = false
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
    }
    
    private func updateCurrentElement() {
        // Remove the last temporary element if it exists
        if let lastElement = elements.last,
           lastElement.timestamp.timeIntervalSinceNow > -0.1 {
            elements.removeLast()
        }
        
        // Add updated current stroke as temporary element
        let tempElement = DrawingElement(
            tool: selectedTool,
            points: currentStroke,
            color: selectedColor,
            thickness: strokeThickness
        )
        elements.append(tempElement)
    }
    
    // MARK: - Eraser Operations
    
    func eraseAt(_ point: CGPoint) {
        saveStateForUndo()
        
        // Find elements that intersect with the eraser point
        let eraserRadius: CGFloat = strokeThickness * 2
        
        elements.removeAll { element in
            element.points.contains { strokePoint in
                let distance = sqrt(pow(strokePoint.x - point.x, 2) + pow(strokePoint.y - point.y, 2))
                return distance <= eraserRadius
            }
        }
        
        redoStack.removeAll()
    }
    
    // MARK: - Undo/Redo Operations
    
    func undo() {
        guard canUndo else { return }
        
        // Save current state to redo stack
        redoStack.append(elements)
        
        // Restore previous state
        if let previousState = undoStack.popLast() {
            elements = previousState
        }
    }
    
    func redo() {
        guard canRedo else { return }
        
        // Save current state to undo stack
        undoStack.append(elements)
        
        // Restore next state
        if let nextState = redoStack.popLast() {
            elements = nextState
        }
    }
    
    private func saveStateForUndo() {
        undoStack.append(elements)
        
        // Limit undo stack size to prevent memory issues
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    // MARK: - Utility Operations
    
    func clearAll() {
        saveStateForUndo()
        elements.removeAll()
        redoStack.removeAll()
    }
    
    func selectTool(_ tool: DrawingTool) {
        selectedTool = tool
    }
}
