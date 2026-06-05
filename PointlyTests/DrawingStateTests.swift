import XCTest
import SwiftUI
@testable import Pointly

final class DrawingStateTests: XCTestCase {
    var drawingState: DrawingState!
    
    override func setUpWithError() throws {
        drawingState = DrawingState()
    }
    
    override func tearDownWithError() throws {
        drawingState = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(drawingState.selectedTool, .pen)
        XCTAssertEqual(drawingState.strokeThickness, 3.0)
        XCTAssertTrue(drawingState.elements.isEmpty)
        XCTAssertFalse(drawingState.canUndo)
        XCTAssertFalse(drawingState.canRedo)
    }
    
    func testDefaultPenColor() {
        // Default pen color should be #FF3B30 (Apple Red)
        let expectedColor = Color(red: 1.0, green: 0.231, blue: 0.188)
        XCTAssertEqual(drawingState.selectedColor, expectedColor)
    }
    
    // MARK: - Drawing Tests
    
    func testStartDrawing() {
        let point = CGPoint(x: 100, y: 100)
        
        drawingState.startDrawing(at: point)
        
        XCTAssertTrue(drawingState.canUndo) // Should have saved state for undo
    }
    
    func testContinueDrawing() {
        let startPoint = CGPoint(x: 100, y: 100)
        let continuePoint = CGPoint(x: 150, y: 150)
        
        drawingState.startDrawing(at: startPoint)
        drawingState.continueDrawing(to: continuePoint)
        
        // Should have at least one element (temporary stroke)
        XCTAssertFalse(drawingState.elements.isEmpty)
    }
    
    func testFinishStroke() {
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 150),
            CGPoint(x: 200, y: 200)
        ]
        
        drawingState.startDrawing(at: points[0])
        for point in points.dropFirst() {
            drawingState.continueDrawing(to: point)
        }
        drawingState.finishStroke()
        
        XCTAssertEqual(drawingState.elements.count, 1)
        
        let element = drawingState.elements.first!
        XCTAssertEqual(element.tool, .pen)
        XCTAssertEqual(element.color, drawingState.selectedColor)
        XCTAssertEqual(element.thickness, drawingState.strokeThickness)
        XCTAssertEqual(element.points.count, points.count)
    }
    
    // MARK: - Tool Selection Tests
    
    func testToolSelection() {
        drawingState.selectTool(.highlighter)
        XCTAssertEqual(drawingState.selectedTool, .highlighter)
        
        drawingState.selectTool(.eraser)
        XCTAssertEqual(drawingState.selectedTool, .eraser)
    }
    
    func testHighlighterOpacity() {
        drawingState.selectTool(.highlighter)
        
        let point = CGPoint(x: 100, y: 100)
        drawingState.startDrawing(at: point)
        drawingState.finishStroke()
        
        let element = drawingState.elements.first!
        XCTAssertEqual(element.opacity, 0.4, accuracy: 0.01)
    }
    
    func testPenOpacity() {
        drawingState.selectTool(.pen)
        
        let point = CGPoint(x: 100, y: 100)
        drawingState.startDrawing(at: point)
        drawingState.finishStroke()
        
        let element = drawingState.elements.first!
        XCTAssertEqual(element.opacity, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Undo/Redo Tests
    
    func testUndo() {
        // Draw something
        let point = CGPoint(x: 100, y: 100)
        drawingState.startDrawing(at: point)
        drawingState.finishStroke()
        
        XCTAssertEqual(drawingState.elements.count, 1)
        XCTAssertTrue(drawingState.canUndo)
        
        // Undo
        drawingState.undo()
        
        XCTAssertEqual(drawingState.elements.count, 0)
        XCTAssertTrue(drawingState.canRedo)
    }
    
    func testRedo() {
        // Draw something
        let point = CGPoint(x: 100, y: 100)
        drawingState.startDrawing(at: point)
        drawingState.finishStroke()
        
        // Undo
        drawingState.undo()
        XCTAssertEqual(drawingState.elements.count, 0)
        
        // Redo
        drawingState.redo()
        XCTAssertEqual(drawingState.elements.count, 1)
        XCTAssertFalse(drawingState.canRedo)
    }
    
    func testUndoRedoStack() {
        // Draw multiple strokes
        for i in 0..<5 {
            let point = CGPoint(x: 100 + i * 10, y: 100 + i * 10)
            drawingState.startDrawing(at: point)
            drawingState.finishStroke()
        }
        
        XCTAssertEqual(drawingState.elements.count, 5)
        
        // Undo all
        for _ in 0..<5 {
            drawingState.undo()
        }
        
        XCTAssertEqual(drawingState.elements.count, 0)
        XCTAssertFalse(drawingState.canUndo)
        
        // Redo all
        for i in 1...5 {
            drawingState.redo()
            XCTAssertEqual(drawingState.elements.count, i)
        }
        
        XCTAssertFalse(drawingState.canRedo)
    }
    
    func testRedoStackClearedOnNewAction() {
        // Draw, undo, then draw again - redo stack should be cleared
        let point1 = CGPoint(x: 100, y: 100)
        drawingState.startDrawing(at: point1)
        drawingState.finishStroke()
        
        drawingState.undo()
        XCTAssertTrue(drawingState.canRedo)
        
        // New action should clear redo stack
        let point2 = CGPoint(x: 200, y: 200)
        drawingState.startDrawing(at: point2)
        drawingState.finishStroke()
        
        XCTAssertFalse(drawingState.canRedo)
    }
    
    // MARK: - Eraser Tests
    
    func testEraser() {
        // Draw a stroke
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 150),
            CGPoint(x: 200, y: 200)
        ]
        
        drawingState.startDrawing(at: points[0])
        for point in points.dropFirst() {
            drawingState.continueDrawing(to: point)
        }
        drawingState.finishStroke()
        
        XCTAssertEqual(drawingState.elements.count, 1)
        
        // Erase at the stroke location
        drawingState.eraseAt(CGPoint(x: 150, y: 150))
        
        XCTAssertEqual(drawingState.elements.count, 0)
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() {
        // Draw multiple strokes
        for i in 0..<3 {
            let point = CGPoint(x: 100 + i * 50, y: 100 + i * 50)
            drawingState.startDrawing(at: point)
            drawingState.finishStroke()
        }
        
        XCTAssertEqual(drawingState.elements.count, 3)
        
        drawingState.clearAll()
        
        XCTAssertEqual(drawingState.elements.count, 0)
        XCTAssertTrue(drawingState.canUndo) // Should be able to undo clear
    }
    
    // MARK: - Performance Tests
    
    func testDrawingPerformance() {
        measure {
            // Simulate drawing a complex stroke
            drawingState.startDrawing(at: CGPoint(x: 0, y: 0))
            
            for i in 0..<1000 {
                let point = CGPoint(x: Double(i), y: sin(Double(i) * 0.1) * 100 + 200)
                drawingState.continueDrawing(to: point)
            }
            
            drawingState.finishStroke()
        }
    }
    
    func testUndoRedoPerformance() {
        // Create many elements
        for i in 0..<100 {
            let point = CGPoint(x: i * 10, y: i * 10)
            drawingState.startDrawing(at: point)
            drawingState.finishStroke()
        }
        
        measure {
            // Undo all
            while drawingState.canUndo {
                drawingState.undo()
            }
            
            // Redo all
            while drawingState.canRedo {
                drawingState.redo()
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyStroke() {
        drawingState.startDrawing(at: CGPoint(x: 100, y: 100))
        drawingState.finishStroke()
        
        // Should still create an element with one point
        XCTAssertEqual(drawingState.elements.count, 1)
        XCTAssertEqual(drawingState.elements.first?.points.count, 1)
    }
    
    func testMultipleStartDrawingCalls() {
        drawingState.startDrawing(at: CGPoint(x: 100, y: 100))
        drawingState.startDrawing(at: CGPoint(x: 200, y: 200)) // Should be ignored
        
        drawingState.continueDrawing(to: CGPoint(x: 150, y: 150))
        drawingState.finishStroke()
        
        let element = drawingState.elements.first!
        XCTAssertEqual(element.points.first, CGPoint(x: 100, y: 100))
    }
    
    func testContinueDrawingWithoutStart() {
        // Should not crash or create elements
        drawingState.continueDrawing(to: CGPoint(x: 100, y: 100))
        drawingState.finishStroke()
        
        XCTAssertEqual(drawingState.elements.count, 0)
    }
}
