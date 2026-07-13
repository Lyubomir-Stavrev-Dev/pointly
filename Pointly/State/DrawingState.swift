import SwiftUI
import Combine

/// Drawing tools available in the toolbar
enum DrawingTool: String, CaseIterable {
    // Core Tools
    case pen = "pen"
    case highlighter = "highlighter"
    case eraser = "eraser"

    // Professional Tools
    case marker = "marker"
    case blurBrush = "blurBrush"
    case laserPointer = "laserPointer"
    case dotPen = "dotPen"
    case cutMove = "cutMove"
    case stepBadge = "stepBadge"
    case fadingPen = "fadingPen"

    // Shape Tools
    case rectangle = "rectangle"
    case ellipse = "ellipse"
    case triangle = "triangle"
    case diamond = "diamond"
    case arrow = "arrow"
    case line = "line"

    // Advanced Tools
    case text = "text"
    case stamp = "stamp"
    case magnifier = "magnifier"
    case spotlight = "spotlight"
    case select = "select"
    case cursor = "cursor"

    var displayName: String {
        switch self {
        case .pen: return "Pen"
        case .highlighter: return "Highlighter"
        case .eraser: return "Eraser"
        case .marker: return "Marker"
        case .blurBrush: return "Blur Brush"
        case .laserPointer: return "Laser Pointer"
        case .dotPen: return "Dot Pen"
        case .cutMove: return "Cut & Move"
        case .stepBadge: return "Step Badge"
        case .fadingPen: return "Fading Ink"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .triangle: return "Triangle"
        case .diamond: return "Diamond"
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .text: return "Text"
        case .stamp: return "Stamp"
        case .magnifier: return "Magnifier"
        case .spotlight: return "Spotlight"
        case .select: return "Select"
        case .cursor: return "Cursor"
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
        case .dotPen: return "circle.dotted"
        case .cutMove: return "scissors"
        case .stepBadge: return "1.circle"
        case .fadingPen: return "scribble.variable"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .triangle: return "triangle"
        case .diamond: return "diamond"
        case .arrow: return "arrow.right"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .stamp: return "stamp"
        case .magnifier: return "magnifyingglass"
        case .spotlight: return "rays"
        case .select: return "lasso"
        case .cursor: return "cursorarrow"
        }
    }

    var description: String {
        switch self {
        case .pen: return "Smooth drawing with pressure sensitivity"
        case .highlighter: return "Semi-transparent highlighting"
        case .eraser: return "Remove annotations"
        case .marker: return "Textured marker with realistic blending"
        case .blurBrush: return "Soft airbrush for emphasis and focus"
        case .laserPointer: return "Animated pointer for presentations"
        case .dotPen: return "Dotted drawing like math diagrams"
        case .cutMove: return "Select an area and drag annotations to a new position"
        case .stepBadge: return "Click to drop auto-numbered badges for walkthroughs"
        case .fadingPen: return "Ink that fades away on its own — never clear the screen"
        case .rectangle: return "Draw rectangular shapes"
        case .ellipse: return "Draw circular and oval shapes"
        case .triangle: return "Draw triangle shapes"
        case .diamond: return "Draw diamond shapes"
        case .arrow: return "Draw arrows with arrowheads"
        case .line: return "Draw straight lines"
        case .text: return "Add text labels"
        case .stamp: return "Insert predefined stamps"
        case .magnifier: return "Magnify screen areas"
        case .spotlight: return "Spotlight effect for presentations"
        case .select: return "Select and move annotations"
        case .cursor: return "Click through to apps behind the overlay"
        }
    }

    /// Whether this tool supports thickness adjustment
    var supportsThickness: Bool {
        switch self {
        case .pen, .marker, .highlighter, .line, .arrow, .dotPen, .fadingPen, .stepBadge:
            return true
        case .blurBrush:
            return true
        case .laserPointer:
            return true
        case .spotlight:
            return true
        case .text:
            return true
        default:
            return false
        }
    }

    /// Whether this tool supports color selection
    var supportsColor: Bool {
        switch self {
        case .eraser, .magnifier, .spotlight, .select, .cursor, .cutMove:
            return false
        default:
            return true
        }
    }
    
    /// Whether this tool creates persistent marks
    var isPersistent: Bool {
        switch self {
        case .laserPointer, .fadingPen:
            return false  // Fades over time
        case .magnifier, .spotlight, .cursor:
            return false  // Real-time effect only
        default:
            return true
        }
    }
    
    /// Whether this tool is a closed shape that supports fill
    var isShape: Bool {
        switch self {
        case .rectangle, .ellipse, .triangle, .diamond: return true
        default: return false
        }
    }

    /// Whether this tool supports thickness adjustment
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
    var points: [CGPoint]
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

    /// Display the element was drawn on. Points are window-LOCAL coordinates,
    /// so an element must only render/hit-test on its own display — a single
    /// shared element list otherwise mirrors annotations onto every screen.
    /// nil (pre-existing saves) renders everywhere.
    var displayID: CGDirectDisplayID? = nil

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
    
    /// Current opacity considering time-based fade.
    /// Laser: fades continuously over 3s. Fading Ink: holds full for 4s so the
    /// audience can read it, then fades out over 1.5s.
    var currentOpacity: Double {
        guard shouldFade else { return opacity }

        let age = Date().timeIntervalSince(timestamp)
        let holdTime: TimeInterval = tool == .fadingPen ? 4.0 : 0
        let fadeTime: TimeInterval = tool == .fadingPen ? 1.5 : 3.0

        if age <= holdTime { return opacity }
        let fadeProgress = (age - holdTime) / fadeTime
        if fadeProgress >= 1 { return 0.0 }
        return opacity * (1.0 - fadeProgress)
    }

    var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        if tool == .text, let t = text, let pt = points.first {
            let fontSize = max(14, thickness * 4)
            let estimatedWidth = max(40, CGFloat(t.count) * fontSize * 0.58 + 12)
            let estimatedHeight = fontSize * 1.5 + 6
            return CGRect(x: pt.x, y: pt.y, width: estimatedWidth, height: estimatedHeight)
        }
        if tool == .stepBadge, let pt = points.first {
            let r = DrawingElement.stepBadgeRadius(for: thickness)
            return CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!,
                      width: xs.max()! - xs.min()!,
                      height: ys.max()! - ys.min()!)
    }

    static func stepBadgeRadius(for thickness: CGFloat) -> CGFloat {
        12 + thickness * 1.5
    }

    func contains(_ point: CGPoint, threshold: CGFloat = 12) -> Bool {
        let box = boundingBox.insetBy(dx: -threshold, dy: -threshold)
        if tool.isShape || tool == .text || tool == .stepBadge { return box.contains(point) }
        guard points.count > 1 else {
            return points.first.map { hypot($0.x - point.x, $0.y - point.y) < threshold } ?? false
        }
        for i in 0..<(points.count - 1) {
            if segmentDistance(from: point, a: points[i], b: points[i + 1]) < threshold { return true }
        }
        return false
    }

    private func segmentDistance(from p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
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
struct LiftedCover: Identifiable {
    let id = UUID()
    let rect: CGRect     // canvas view coordinates (SwiftUI, top-left)
    let image: NSImage?  // background screenshot if available
    let fillColor: Color // solid-color fallback (sampled from captured image edges)
    var displayID: CGDirectDisplayID? = nil   // display the capture happened on
}

class DrawingState: ObservableObject {
    // Published properties for UI binding
    @Published var selectedTool: DrawingTool = .pen
    @Published var selectedColor: Color = Color(hex: "#F4644D") ?? Color(red: 0.957, green: 0.392, blue: 0.302)
    @Published var strokeThickness: CGFloat = 3.0
    private var toolThicknesses: [DrawingTool: CGFloat] = [:]
    @Published var isFilled: Bool = false
    @Published var selectedElementIDs: Set<UUID> = []
    @Published var selectionRubberBand: CGRect? = nil
    @Published var isTextInputActive: Bool = false
    @Published var liftedCovers: [LiftedCover] = []
    @Published var whiteboardMode: Bool = false

    // Drawing elements and undo/redo stacks
    @Published private(set) var elements: [DrawingElement] = []
    private var undoStack: [[DrawingElement]] = []
    private var redoStack: [[DrawingElement]] = []
    
    // Current drawing state
    private var currentStroke: [CGPoint] = []
    private var isDrawing = false
    private var tempElementID: UUID? = nil   // tracks in-progress preview element

    /// Display the current gesture is happening on — set by the OverlayView
    /// that owns the gesture (one per screen sharing this state). New elements
    /// are stamped with it and hit-testing is scoped to it.
    var activeDisplayID: CGDirectDisplayID? = nil

    private func onActiveDisplay(_ e: DrawingElement) -> Bool {
        e.displayID == nil || activeDisplayID == nil || e.displayID == activeDisplayID
    }
    
    // Computed properties for undo/redo availability
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }

    var selectedBoundingBox: CGRect? {
        let sel = elements.filter { selectedElementIDs.contains($0.id) }
        guard !sel.isEmpty else { return nil }
        return sel.map(\.boundingBox).dropFirst().reduce(sel[0].boundingBox) { $0.union($1) }
    }

    var selectedElementsAreAllText: Bool {
        let sel = elements.filter { selectedElementIDs.contains($0.id) }
        return !sel.isEmpty && sel.allSatisfy { $0.tool == .text }
    }

    init() {
        // Apply saved default color and thickness from Settings
        let colorHex = UserDefaults.standard.string(forKey: "defaultPenColor") ?? "#F4644D"
        selectedColor = Color(hex: colorHex) ?? (Color(hex: "#F4644D") ?? Color(red: 0.957, green: 0.392, blue: 0.302))
        let savedThickness = UserDefaults.standard.double(forKey: "defaultThickness")
        strokeThickness = savedThickness > 0 ? CGFloat(savedThickness) : 3.0
        // No baseline undo push here — every mutation pushes before changing,
        // so an empty stack correctly means "nothing to undo" at launch.
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

    // Effective assist level: "off" / "low" / "high". High is Pro-only —
    // enforced here too so editing defaults can't unlock it.
    private var straightLineAssistLevel: String {
        let level = UserDefaults.standard.string(forKey: "straightLineAssistLevel") ?? "low"
        if level == "high" && !ProManager.shared.isPro { return "low" }
        return level
    }

    private func applyDrawingAssistance(_ point: CGPoint) -> CGPoint {
        var result = point
        // Snap to grid
        if UserDefaults.standard.bool(forKey: "snapToGrid") {
            let saved = UserDefaults.standard.double(forKey: "gridSize")
            let gridSize: CGFloat = saved > 0 ? CGFloat(saved) : 20
            result = CGPoint(
                x: round(result.x / gridSize) * gridSize,
                y: round(result.y / gridSize) * gridSize
            )
        }
        // Straight-line assist: for shape tools, only keep start + current endpoint
        let assist = straightLineAssistLevel
        let shapeTools: Set<DrawingTool> = [.rectangle, .ellipse, .triangle, .diamond]
        if assist != "off",
           ([DrawingTool.line, .arrow].contains(selectedTool) || shapeTools.contains(selectedTool)),
           let first = currentStroke.first {
            currentStroke = [first]
            if assist == "high" {
                if [DrawingTool.line, .arrow].contains(selectedTool) {
                    // Strong pull to 0/45/90°, gentle 15° detents
                    result = snapAngle(from: first, to: result)
                } else if shapeTools.contains(selectedTool) {
                    // Snap a near-square drag to a perfect square/circle
                    result = snapSquare(from: first, to: result)
                }
            }
        }
        return result
    }

    private func snapAngle(from origin: CGPoint, to point: CGPoint) -> CGPoint {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let dist = hypot(dx, dy)
        guard dist > 8 else { return point }
        let deg = atan2(dy, dx) * 180 / .pi
        let major = (deg / 45).rounded() * 45
        let minor = (deg / 15).rounded() * 15
        let snapped: CGFloat
        if abs(deg - major) <= 6 { snapped = major }        // 0/45/90 feel magnetic
        else if abs(deg - minor) <= 3.5 { snapped = minor } // light 15° detents
        else { return point }
        let rad = snapped * .pi / 180
        return CGPoint(x: origin.x + dist * cos(rad), y: origin.y + dist * sin(rad))
    }

    // When the drag is roughly square (within 18%), force equal width/height so
    // ellipse → perfect circle and rectangle/triangle/diamond → regular shape.
    // Keeps the drag direction (sign) so the shape grows the way you dragged.
    private func snapSquare(from origin: CGPoint, to point: CGPoint) -> CGPoint {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let w = abs(dx), h = abs(dy)
        guard w > 8, h > 8 else { return point }
        let ratio = min(w, h) / max(w, h)
        guard ratio >= 0.82 else { return point }   // only near-squares snap
        let side = max(w, h)
        return CGPoint(x: origin.x + (dx < 0 ? -side : side),
                       y: origin.y + (dy < 0 ? -side : side))
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

        // Remove the preview/temp element before appending the final committed element
        removeTempElement()

        // Shapes render only from first→last point — keeping every intermediate
        // drag point bloats memory and makes boundingBox track the drag path
        // instead of the rendered geometry (selection handles float away).
        let shapeTools: Set<DrawingTool> = [.line, .arrow, .rectangle, .ellipse, .triangle, .diamond]
        if shapeTools.contains(selectedTool), currentStroke.count > 2,
           let first = currentStroke.first, let last = currentStroke.last {
            currentStroke = [first, last]
        }

        // High assist (Pro): a nearly-straight pen stroke snaps to a perfect line.
        if selectedTool == .pen, straightLineAssistLevel == "high",
           currentStroke.count > 2,
           let first = currentStroke.first, let last = currentStroke.last {
            let chord = hypot(last.x - first.x, last.y - first.y)
            if chord > 40 {
                // Max perpendicular deviation of any point from the first→last chord
                let maxDeviation = currentStroke.map { p -> CGFloat in
                    abs((last.x - first.x) * (first.y - p.y) - (first.x - p.x) * (last.y - first.y)) / chord
                }.max() ?? 0
                if maxDeviation < max(6, chord * 0.025) {
                    currentStroke = [first, last]
                }
            }
        }

        var element = createDrawingElement()
        element.displayID = activeDisplayID
        applyArrowDirection(&element)
        elements.append(element)
        currentStroke.removeAll()
        isDrawing = false
        redoStack.removeAll()
        handleToolSpecificPostProcessing(element)
        saveAnnotations()
    }
    
    /// Drop an auto-numbered step badge — number = existing badge count + 1,
    /// so undo/erase renumbers naturally on the next placement.
    func addStepBadge(at point: CGPoint) {
        saveStateForUndo()
        let next = elements.filter { $0.tool == .stepBadge }.count + 1
        var element = DrawingElement(
            tool: .stepBadge,
            points: [point],
            color: selectedColor,
            thickness: strokeThickness,
            text: "\(next)"
        )
        element.displayID = activeDisplayID
        elements.append(element)
        redoStack.removeAll()
        saveAnnotations()
    }

    /// Add a text annotation at a specific point
    func addTextElement(at point: CGPoint, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saveStateForUndo()
        var element = DrawingElement(
            tool: .text,
            points: [point],
            color: selectedColor,
            thickness: strokeThickness,
            text: text
        )
        element.displayID = activeDisplayID
        elements.append(element)
        redoStack.removeAll()
        saveAnnotations()
    }

    /// Cancel the current in-progress stroke without adding it to elements
    func cancelCurrentStroke() {
        guard isDrawing else { return }
        removeTempElement()
        if !undoStack.isEmpty { undoStack.removeLast() }
        currentStroke.removeAll()
        isDrawing = false
    }

    private func removeTempElement() {
        guard let id = tempElementID else { return }
        elements.removeAll { $0.id == id }
        tempElementID = nil
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

        case .dotPen:
            return DrawingElement(
                tool: selectedTool,
                points: currentStroke,
                color: selectedColor,
                thickness: strokeThickness
            )

        default:
            let fillable = [DrawingTool.rectangle, .ellipse, .triangle, .diamond].contains(selectedTool)
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
            scheduleRemoval(of: element, after: 3.5)
        case .fadingPen:
            scheduleRemoval(of: element, after: 6.0)   // 4s hold + 1.5s fade + margin
        default:
            break
        }
    }
    
    private func scheduleRemoval(of element: DrawingElement, after delay: TimeInterval) {
        // Remove faded transient elements once fully invisible
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.elements.removeAll { $0.id == element.id }
        }
    }
    
    private func updateCurrentElement() {
        removeTempElement()
        var tempElement = createDrawingElement()
        tempElement.displayID = activeDisplayID
        applyArrowDirection(&tempElement)
        tempElementID = tempElement.id
        elements.append(tempElement)
    }

    // Arrow tip lands where the user first pressed (default) — reverse the
    // points so drawArrow's tip (last point) is the press point. Baked into
    // the element so toggling the setting doesn't flip existing arrows.
    private func applyArrowDirection(_ element: inout DrawingElement) {
        guard element.tool == .arrow,
              UserDefaults.standard.bool(forKey: "arrowTipAtStart") else { return }
        element.points.reverse()
    }
    
    // MARK: - Eraser Operations

    // Call once at the start of an eraser drag to capture undo state.
    func beginEraseStroke() {
        saveStateForUndo()
        redoStack.removeAll()
    }

    // Call on every drag point — no undo save (beginEraseStroke owns that).
    func eraseAt(_ point: CGPoint) {
        let radius: CGFloat = max(24, strokeThickness * 3)
        // Scoped to the gesture's display — same local coords exist on every
        // screen, so an unscoped erase deletes another display's annotations.
        elements.removeAll { onActiveDisplay($0) && $0.contains(point, threshold: radius) }
    }
    
    // MARK: - Undo/Redo Operations
    
    var onWillUndo:     (() -> Void)?
    var onWillRedo:     (() -> Void)?
    var onWillClearAll: (() -> Void)?

    func undo() {
        guard canUndo else { return }
        onWillUndo?()
        redoStack.append(snapshotElements())
        if let previousState = undoStack.popLast() {
            elements = previousState
        }
        saveAnnotations()   // otherwise an undone stroke returns after relaunch
    }

    func redo() {
        // Fire hook before the guard so lifted captures are dismissed even
        // when canRedo is false (the button is enabled whenever captures exist).
        onWillRedo?()
        guard canRedo else { return }
        undoStack.append(snapshotElements())
        if let nextState = redoStack.popLast() {
            elements = nextState
        }
        saveAnnotations()
    }

    private func saveStateForUndo() {
        undoStack.append(snapshotElements())

        // Limit undo stack size to prevent memory issues
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    // Transient strokes (laser, fading ink) don't belong in undo/redo
    // snapshots — restoring a fully-faded (invisible) element that nothing
    // removes again pins the TimelineView at 60fps forever.
    private func snapshotElements() -> [DrawingElement] {
        elements.filter { $0.tool.isPersistent }
    }
    
    // For snapshot rendering only — loads elements without touching undo/redo.
    func loadForSnapshot(_ newElements: [DrawingElement]) {
        elements = newElements
    }

    // MARK: - Utility Operations

    func clearAll() {
        onWillClearAll?()
        saveStateForUndo()
        elements.removeAll()
        redoStack.removeAll()
        saveAnnotations()
    }
    
    func selectTool(_ tool: DrawingTool) {
        toolThicknesses[selectedTool] = strokeThickness
        selectedTool = tool
        let defaultThickness: CGFloat = {
            let v = UserDefaults.standard.double(forKey: "defaultThickness")
            return v > 0 ? CGFloat(v) : 3.0
        }()
        strokeThickness = toolThicknesses[tool] ?? defaultThickness
        NotificationCenter.default.post(name: .toolChanged, object: tool)
    }

    // MARK: - Selection

    func hitTest(at point: CGPoint, threshold: CGFloat = 12) -> DrawingElement? {
        elements.reversed().first { onActiveDisplay($0) && $0.contains(point, threshold: threshold) }
    }

    func clearSelection() { selectedElementIDs = [] }

    func selectElement(id: UUID, addToSelection: Bool = false) {
        if addToSelection { selectedElementIDs.insert(id) }
        else { selectedElementIDs = [id] }
    }

    func selectElements(in rect: CGRect) {
        selectedElementIDs = Set(elements.filter { onActiveDisplay($0) && rect.intersects($0.boundingBox) }.map(\.id))
    }

    // Call once at the start of a move/resize drag — one undo snapshot for the
    // whole drag (per-event snapshots flooded the 50-slot undo stack) and a
    // fresh redo baseline. Mirror of beginEraseStroke().
    func beginTransform() {
        saveStateForUndo()
        redoStack.removeAll()
    }

    // Call once at drag end — persisting per mouse-move event was a full JSON
    // encode + atomic file write on every pixel of the drag.
    func commitTransform() {
        saveAnnotations()
    }

    func moveSelected(by delta: CGSize) {
        guard !selectedElementIDs.isEmpty else { return }
        for i in elements.indices where selectedElementIDs.contains(elements[i].id) {
            elements[i].points = elements[i].points.map {
                CGPoint(x: $0.x + delta.width, y: $0.y + delta.height)
            }
        }
    }

    func resizeFromSnapshot(_ snapshot: [(UUID, [CGPoint])], from oldBox: CGRect, to newBox: CGRect) {
        guard oldBox.width > 1, oldBox.height > 1 else { return }
        for (id, originalPts) in snapshot {
            guard let idx = elements.firstIndex(where: { $0.id == id }) else { continue }
            elements[idx].points = originalPts.map { pt in
                CGPoint(
                    x: newBox.minX + (pt.x - oldBox.minX) / oldBox.width  * newBox.width,
                    y: newBox.minY + (pt.y - oldBox.minY) / oldBox.height * newBox.height
                )
            }
        }
    }

    func deleteSelected() {
        guard !selectedElementIDs.isEmpty else { return }
        saveStateForUndo()
        elements.removeAll { selectedElementIDs.contains($0.id) }
        selectedElementIDs = []
        redoStack.removeAll()
        saveAnnotations()
    }

    func deleteElements(in rect: CGRect) {
        saveStateForUndo()
        elements.removeAll { onActiveDisplay($0) && rect.intersects($0.boundingBox) }
        selectedElementIDs = []
        redoStack.removeAll()
        saveAnnotations()
    }

    @discardableResult
    func addLiftedCover(rect: CGRect, image: NSImage?, fillColor: Color,
                        displayID: CGDirectDisplayID? = nil) -> UUID {
        let cover = LiftedCover(rect: rect, image: image, fillColor: fillColor, displayID: displayID)
        liftedCovers.append(cover)
        return cover.id
    }

    func removeLiftedCover(id: UUID) {
        liftedCovers.removeAll { $0.id == id }
    }

    func clearLiftedCovers() {
        liftedCovers.removeAll()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let toolChanged         = Notification.Name("ToolChanged")
    static let startLaserAnimation = Notification.Name("StartLaserAnimation")
    static let cancelTextInput     = Notification.Name("CancelTextInput")
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
    var displayID: UInt32? = nil   // optional → old saves decode fine
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
                isFilled: el.isFilled,
                displayID: el.displayID
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
            var element = DrawingElement(
                tool: tool,
                points: points,
                color: Color(hex: p.colorHex) ?? .red,
                thickness: CGFloat(p.thickness),
                blurRadius: p.blurRadius.map { CGFloat($0) },
                glowIntensity: p.glowIntensity.map { CGFloat($0) },
                text: p.text,
                isFilled: p.isFilled
            )
            element.displayID = p.displayID
            return element
        }
        if !loaded.isEmpty {
            saveStateForUndo()
            elements = loaded
        }
    }
}
