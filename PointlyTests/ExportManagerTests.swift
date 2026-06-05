import XCTest
import SwiftUI
@testable import Pointly

final class ExportManagerTests: XCTestCase {
    var exportManager: ExportManager!
    var drawingState: DrawingState!
    
    override func setUpWithError() throws {
        exportManager = ExportManager()
        drawingState = DrawingState()
    }
    
    override func tearDownWithError() throws {
        exportManager = nil
        drawingState = nil
    }
    
    // MARK: - Export Format Tests
    
    func testExportFormatProperties() {
        let pngFormat = ExportManager.ExportFormat.png
        XCTAssertEqual(pngFormat.displayName, "PNG Image")
        XCTAssertEqual(pngFormat.fileExtension, "png")
        
        let pdfFormat = ExportManager.ExportFormat.pdf
        XCTAssertEqual(pdfFormat.displayName, "PDF Document")
        XCTAssertEqual(pdfFormat.fileExtension, "pdf")
        
        let jpegFormat = ExportManager.ExportFormat.jpeg
        XCTAssertEqual(jpegFormat.displayName, "JPEG Image")
        XCTAssertEqual(jpegFormat.fileExtension, "jpeg")
    }
    
    func testAllExportFormats() {
        let allFormats = ExportManager.ExportFormat.allCases
        XCTAssertEqual(allFormats.count, 3)
        XCTAssertTrue(allFormats.contains(.png))
        XCTAssertTrue(allFormats.contains(.pdf))
        XCTAssertTrue(allFormats.contains(.jpeg))
    }
    
    // MARK: - Export Tests
    
    func testExportEmptyDrawing() {
        let expectation = XCTestExpectation(description: "Export empty drawing")
        
        exportManager.exportDrawing(
            drawingState,
            format: .png,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("Export should succeed for empty drawing: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExportWithDrawingElements() {
        // Add some drawing elements
        drawingState.selectTool(.pen)
        drawingState.startDrawing(at: CGPoint(x: 100, y: 100))
        drawingState.continueDrawing(to: CGPoint(x: 200, y: 200))
        drawingState.finishStroke()
        
        drawingState.selectTool(.highlighter)
        drawingState.startDrawing(at: CGPoint(x: 150, y: 150))
        drawingState.continueDrawing(to: CGPoint(x: 250, y: 250))
        drawingState.finishStroke()
        
        let expectation = XCTestExpectation(description: "Export drawing with elements")
        
        exportManager.exportDrawing(
            drawingState,
            format: .png,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Verify file size is reasonable (not empty)
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes?[.size] as? Int ?? 0
                XCTAssertGreaterThan(fileSize, 100) // Should be more than 100 bytes
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("Export should succeed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExportPDFFormat() {
        // Add a simple drawing element
        drawingState.startDrawing(at: CGPoint(x: 100, y: 100))
        drawingState.continueDrawing(to: CGPoint(x: 200, y: 200))
        drawingState.finishStroke()
        
        let expectation = XCTestExpectation(description: "Export PDF")
        
        exportManager.exportDrawing(
            drawingState,
            format: .pdf,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                XCTAssertTrue(url.pathExtension == "pdf")
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("PDF export should succeed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExportJPEGFormat() {
        // Add a simple drawing element
        drawingState.startDrawing(at: CGPoint(x: 100, y: 100))
        drawingState.continueDrawing(to: CGPoint(x: 200, y: 200))
        drawingState.finishStroke()
        
        let expectation = XCTestExpectation(description: "Export JPEG")
        
        exportManager.exportDrawing(
            drawingState,
            format: .jpeg,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                XCTAssertTrue(url.pathExtension == "jpeg")
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("JPEG export should succeed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testExportPerformance() {
        // Create a complex drawing
        for i in 0..<100 {
            let startPoint = CGPoint(x: Double(i * 5), y: Double(i * 3))
            let endPoint = CGPoint(x: Double(i * 5 + 50), y: Double(i * 3 + 50))
            
            drawingState.startDrawing(at: startPoint)
            drawingState.continueDrawing(to: endPoint)
            drawingState.finishStroke()
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Export performance")
            
            exportManager.exportDrawing(
                drawingState,
                format: .png,
                size: CGSize(width: 1920, height: 1080)
            ) { result in
                if case .success(let url) = result {
                    try? FileManager.default.removeItem(at: url)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testExportWithInvalidSize() {
        let expectation = XCTestExpectation(description: "Export with invalid size")
        
        exportManager.exportDrawing(
            drawingState,
            format: .png,
            size: CGSize(width: 0, height: 0)
        ) { result in
            switch result {
            case .success:
                XCTFail("Export should fail with invalid size")
            case .failure:
                // Expected to fail
                break
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Drawing Element Export Tests
    
    func testExportDifferentTools() {
        let tools: [DrawingTool] = [.pen, .highlighter, .rectangle, .ellipse, .line, .arrow]
        
        for (index, tool) in tools.enumerated() {
            drawingState.selectTool(tool)
            
            let startPoint = CGPoint(x: 100 + index * 50, y: 100 + index * 50)
            let endPoint = CGPoint(x: 150 + index * 50, y: 150 + index * 50)
            
            drawingState.startDrawing(at: startPoint)
            drawingState.continueDrawing(to: endPoint)
            drawingState.finishStroke()
        }
        
        let expectation = XCTestExpectation(description: "Export different tools")
        
        exportManager.exportDrawing(
            drawingState,
            format: .png,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("Export with different tools should succeed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExportWithDifferentColors() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple]
        
        for (index, color) in colors.enumerated() {
            drawingState.selectedColor = color
            
            let point = CGPoint(x: 100 + index * 50, y: 100)
            drawingState.startDrawing(at: point)
            drawingState.continueDrawing(to: CGPoint(x: point.x, y: point.y + 100))
            drawingState.finishStroke()
        }
        
        let expectation = XCTestExpectation(description: "Export different colors")
        
        exportManager.exportDrawing(
            drawingState,
            format: .png,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("Export with different colors should succeed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExportWithDifferentThickness() {
        let thicknesses: [CGFloat] = [1, 3, 5, 8, 10]
        
        for (index, thickness) in thicknesses.enumerated() {
            drawingState.strokeThickness = thickness
            
            let point = CGPoint(x: 100, y: 100 + index * 50)
            drawingState.startDrawing(at: point)
            drawingState.continueDrawing(to: CGPoint(x: point.x + 100, y: point.y))
            drawingState.finishStroke()
        }
        
        let expectation = XCTestExpectation(description: "Export different thickness")
        
        exportManager.exportDrawing(
            drawingState,
            format: .png,
            size: CGSize(width: 800, height: 600)
        ) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
                
            case .failure(let error):
                XCTFail("Export with different thickness should succeed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
