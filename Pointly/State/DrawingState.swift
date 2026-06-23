import SwiftUI
import Combine

/// Drawing tools available in the toolbar
/// 
/// **Phase 2.1 Expansion**: Added professional tools for immediate impact
/// - Marker: Textured, realistic marker with blending
/// - BlurBrush: Screen-space blur effect for emphasis
/// - LaserPointer: Animated pointer with fade for presentations
enum DrawingTool: String, CaseIterable {
    // Core Tools (Phase 1)
    case pen = "pen"
    case highlighter = "highlighter"
    case eraser = "eraser"
    
    // Professional Tools (Phase 2.1)
    case marker = "marker"
    case blurBrush = "blurBrush"
    case laserPointer = "laserPointer"
    
    // Shape Tools
    case rectangle = "rectangle"
    case ellipse = "ellipse"
    case arrow = "arrow"
    case line = "line"
    
    // Advanced Tools (Future)
    case text = "text"
    case stamp = "stamp"
    case magnifier = "magnifier"
    
    var displayName: String {
        switch self {
        case .pen: return "Pen"
        case .highlighter: return "Highlighter"
        case .eraser: return "Eraser"
        case .marker: return "Marker"
        case .blurBrush: return "Blur Brush"
        case .laserPointer: return "Laser Pointer"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .text: return "Text"
        case .stamp: return "Stamp"
        case .magnifier: return "Magnifier"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pen: return "pencil"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .marker: return "paintbrush"
        case .blurBrush: return "camera.filters"
        case .laserPointer: return "laser.burst"
        case .rectangle: return "rectangle"
        case .ellipse: return "ellipse"
        case .arrow: return "arrow.right"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .stamp: return "stamp"
        case .magnifier: return "magnifyingglass"
        }
    }
    
    var description: String {
        switch self {
        case .pen: return "Smooth drawing with pressure sensitivity"
        case .highlighter: return "Semi-transparent highlighting"
        case .eraser: return "Remove annotations"
        case .marker: return "Textured marker with realistic blending"
        case .blurBrush: return "Blur effect for emphasis and focus"
        case .laserPointer: return "Animated pointer for presentations"
        case .rectangle: return "Draw rectangular shapes"
        case .ellipse: return "Draw circular and oval shapes"
        case .arrow: return "Draw arrows with arrowheads"
        case .line: return "Draw straight lines"
        case .text: return "Add text labels"
        case .stamp: return "Insert predefined stamps"
        case .magnifier: return "Magnify screen areas"
        }
    }
    
    /// Whether this tool supports thickness adjustment
    var supportsThickness: Bool {
        switch self {
        case .pen, .marker, .highlighter, .line, .arrow:
            return true
        case .blurBrush:
            return true  // Controls blur radius
        case .laserPointer:
            return true  // Controls glow intensity
        default:
            return false
        }
    }
    
    /// Whether this tool supports color selection
    var supportsColor: Bool {
        switch self {
        case .eraser, .magnifier:
            return false
        default:
            return true
        }
    }
    
    /// Whether this tool creates persistent marks
    var isPersistent: Bool {
        switch self {
        case .laserPointer:
            return false  // Fades over time
        case .magnifier:
            return false  // Real-time effect only
        default:
            return true
        }
    }
    
    /// Default opacity for this tool
    var defaultOpacity: Double {
        switch self {
        case .highlighter:
            return 0.4
        case .marker:
            return 0.8
        case .laserPointer:
            return 1.0
        case .blurBrush:
            return 0.6
        default:
            return 1.0
        }
    }
}

/// Represents a single drawing stroke or shape
/// 
/// **Phase 2.1 Enhancement**: Extended to support new tool properties
struct DrawingElement: Identifiable {
    let id = UUID()
    let tool: DrawingTool
    let points: [CGPoint]
    let color: Color
    let thickness: CGFloat
    let opacity: Double
    let timestamp: Date
    
    // Advanced properties for new tools
    let blurRadius: CGFloat?        // For blur brush
    let glowIntensity: CGFloat?     // For laser pointer
    let textureType: TextureType?   // For marker
    let animationSpeed: CGFloat?    // For animated tools
    let text: String?               // For text tool
    let isFilled: Bool              // For shape fills (rectangle, ellipse)

    init(tool: DrawingTool, points: [CGPoint], color: Color, thickness: CGFloat,
         blurRadius: CGFloat? = nil, glowIntensity: CGFloat? = nil,
         textureType: TextureType? = nil, animationSpeed: CGFloat? = nil,
         text: String? = nil, isFilled: Bool = false) {
        self.tool = tool
        self.points = points
        self.color = color
        self.thickness = thickness
        self.opacity = tool.defaultOpacity
        self.timestamp = Date()
        self.blurRadius = blurRadius
        self.glowIntensity = glowIntensity
        self.textureType = textureType
        self.animationSpeed = animationSpeed
        self.text = text
        self.isFilled = isFilled
    }
    
    /// Whether this element should fade over time (laser pointer)
    var shouldFade: Bool {
        return !tool.isPersistent
    }
    
    /// Current opacity considering time-based fade
    var currentOpacity: Double {
        guard shouldFade else { return opacity }
        
        let age = Date().timeIntervalSince(timestamp)
        let fadeTime: TimeInterval = 3.0  // 3 seconds for laser pointer
        
        if age >= fadeTime {
            return 0.0
        }
        
        let fadeProgress = age / fadeTime
        return opacity * (1.0 - fadeProgress)
    }
}

/// Texture types for advanced tools
enum TextureType: String, CaseIterable {
    case smooth = "smooth"
    case rough = "rough"
    case canvas = "canvas"
    case paper = "paper"
    case marker = "marker"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

/// Main state manager for drawing operations
class DrawingState: ObservableObject {
    // Published properties for UI binding
    @Published var selectedTool: DrawingTool = .pen
    @Published var selectedColor: Color = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
    @Published var strokeThickness: CGFloat = 3.0
    @Published var isFilled: Bool = false
    
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
        
        // Tool-specific initialization
        initializeToolSpecificProperties()
    }
    
    func continueDrawing(to point: CGPoint) {
        guard isDrawing else { return }
        let processed = applyDrawingAssistance(point)
        currentStroke.append(processed)
        updateCurrentElement()
    }

    private func applyDrawingAssistance(_ point: CGPoint) -> CGPoint {
        var result = point
        // Snap to grid
        if UserDefaults.standard.bool(forKey: "snapToGrid") {
            let gridSize: CGFloat = 20
            result = CGPoint(
                x: round(result.x / gridSize) * gridSize,
                y: round(result.y / gridSize) * gridSize
            )
        }
        // Straight-line assist: for shape tools, only keep start + current endpoint
        if UserDefaults.standard.bool(forKey: "straightLineAssist"),
           [DrawingTool.line, .arrow, .rectangle, .ellipse].contains(selectedTool),
           let first = currentStroke.first {
            currentStroke = [first]
        }
        return result
    }
    
    private func initializeToolSpecificProperties() {
        // Set tool-specific defaults when starting a new stroke
        switch selectedTool {
        case .marker:
            // Marker uses texture-based rendering
            break
        case .blurBrush:
            // Blur brush needs screen capture for effect
            break
        case .laserPointer:
            // Laser pointer starts with full intensity
            break
        default:
            break
        }
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

        let element = createDrawingElement()
        elements.append(element)
        currentStroke.removeAll()
        isDrawing = false
        redoStack.removeAll()
        handleToolSpecificPostProcessing(element)
        saveAnnotations()
    }
    
    /// Add a text annotation at a specific point
    func addTextElement(at point: CGPoint, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saveStateForUndo()
        let element = DrawingElement(
            tool: .text,
            points: [point],
            color: selectedColor,
            thickness: strokeThickness,
            text: text
        )
        elements.append(element)
        redoStack.removeAll()
        saveAnnotations()
    }

    /// Cancel the current in-progress stroke without adding it to elements
    func cancelCurrentStroke() {
        guard isDrawing else { return }
        // Remove the temp element added by updateCurrentElement
        if let last = elements.last, last.timestamp.timeIntervalSinceNow > -0.5 {
            elements.removeLast()
        }
        // Remove the undo state saved at startDrawing
        if !undoStack.isEmpty {
            undoStack.removeLast()
        }
        currentStroke.removeAll()
        isDrawing = false
    }

    private func createDrawingElement() -> DrawingElement {
        // Create element with tool-specific properties
        switch selectedTool {
        case .marker:
            return DrawingElement(
                tool: selectedTool,
                points: currentStroke,
                color: selectedColor,
                thickness: strokeThickness,
                textureType: .marker
            )
            
        case .blurBrush:
            return DrawingElement(
                tool: selectedTool,
                points: currentStroke,
                color: selectedColor,
                thickness: strokeThickness,
                blurRadius: strokeThickness * 2.0
            )
            
        case .laserPointer:
            return DrawingElement(
                tool: selectedTool,
                points: currentStroke,
                color: selectedColor,
                thickness: strokeThickness,
                glowIntensity: strokeThickness * 1.5,
                animationSpeed: 1.0
            )
            
        default:
            let fillable = selectedTool == .rectangle || selectedTool == .ellipse
            return DrawingElement(
                tool: selectedTool,
                points: currentStroke,
                color: selectedColor,
                thickness: strokeThickness,
                isFilled: fillable ? isFilled : false
            )
        }
    }
    
    private func handleToolSpecificPostProcessing(_ element: DrawingElement) {
        switch element.tool {
        case .laserPointer:
            // Schedule fade-out for laser pointer
            scheduleLaserPointerFade(element)
            
        case .blurBrush:
            // Trigger screen blur effect
            triggerScreenBlurEffect(element)
            
        default:
            break
        }
    }
    
    private func scheduleLaserPointerFade(_ element: DrawingElement) {
        // Remove laser pointer elements after fade time
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.elements.removeAll { $0.id == element.id }
        }
    }
    
    private func triggerScreenBlurEffect(_ element: DrawingElement) {
        // Notify Metal renderer to apply blur effect
        NotificationCenter.default.post(
            name: .applyBlurEffect,
            object: element
        )
    }
    
    private func updateCurrentElement() {
        // Remove the last temporary element if it exists
        if let lastElement = elements.last,
           lastElement.timestamp.timeIntervalSinceNow > -0.1 {
            elements.removeLast()
        }
        
        // Add updated current stroke as temporary element
        let tempElement = createDrawingElement()
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
        saveAnnotations()
    }
    
    func selectTool(_ tool: DrawingTool) {
        selectedTool = tool
        
        // Update UI for tool-specific properties
        NotificationCenter.default.post(
            name: .toolChanged,
            object: tool
        )
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let toolChanged        = Notification.Name("ToolChanged")
    static let applyBlurEffect    = Notification.Name("ApplyBlurEffect")
    static let startLaserAnimation = Notification.Name("StartLaserAnimation")
}

// MARK: - Persistence

/// Codable mirror of DrawingElement for JSON serialisation
private struct PersistedElement: Codable {
    let tool: String
    let points: [[Double]]   // [[x, y], ...]
    let colorHex: String
    let thickness: Double
    let opacity: Double
    let blurRadius: Double?
    let glowIntensity: Double?
    let text: String?
    let isFilled: Bool
}

extension DrawingState {

    private static var saveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pointly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("annotations.json")
    }

    /// Persist all current (non-fading) elements to disk.
    func saveAnnotations() {
        guard UserDefaults.standard.bool(forKey: "autoSaveAnnotations") else { return }
        let persistent = elements.filter { $0.tool.isPersistent }
        let encoded = persistent.map { el -> PersistedElement in
            PersistedElement(
                tool: el.tool.rawValue,
                points: el.points.map { [$0.x, $0.y] },
                colorHex: el.color.toHex(),
                thickness: el.thickness,
                opacity: el.opacity,
                blurRadius: el.blurRadius.map { Double($0) },
                glowIntensity: el.glowIntensity.map { Double($0) },
                text: el.text,
                isFilled: el.isFilled
            )
        }
        if let data = try? JSONEncoder().encode(encoded) {
            try? data.write(to: Self.saveURL, options: .atomic)
        }
    }

    /// Load previously saved annotations from disk.
    func loadAnnotations() {
        guard UserDefaults.standard.bool(forKey: "autoSaveAnnotations"),
              let data = try? Data(contentsOf: Self.saveURL),
              let decoded = try? JSONDecoder().decode([PersistedElement].self, from: data)
        else { return }

        let loaded: [DrawingElement] = decoded.compactMap { p in
            guard let tool = DrawingTool(rawValue: p.tool) else { return nil }
            let points = p.points.compactMap { arr -> CGPoint? in
                guard arr.count == 2 else { return nil }
                return CGPoint(x: arr[0], y: arr[1])
            }
            guard !points.isEmpty else { return nil }
            return DrawingElement(
                tool: tool,
                points: points,
                color: Color(hex: p.colorHex) ?? .red,
                thickness: CGFloat(p.thickness),
                blurRadius: p.blurRadius.map { CGFloat($0) },
                glowIntensity: p.glowIntensity.map { CGFloat($0) },
                text: p.text,
                isFilled: p.isFilled
            )
        }
        if !loaded.isEmpty {
            saveStateForUndo()
            elements = loaded
        }
    }
}
