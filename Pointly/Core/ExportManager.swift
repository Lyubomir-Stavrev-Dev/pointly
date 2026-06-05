import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Manages exporting annotations to various formats
class ExportManager: ObservableObject {
    
    /// Export formats supported by Pointly
    enum ExportFormat: String, CaseIterable {
        case png = "png"
        case pdf = "pdf"
        case jpeg = "jpeg"
        
        var displayName: String {
            switch self {
            case .png: return "PNG Image"
            case .pdf: return "PDF Document"
            case .jpeg: return "JPEG Image"
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
        
        var utType: UTType {
            switch self {
            case .png: return .png
            case .pdf: return .pdf
            case .jpeg: return .jpeg
            }
        }
    }
    
    /// Export the current drawing state to a file
    /// - Parameters:
    ///   - drawingState: The current drawing state to export
    ///   - format: Export format (PNG, PDF, JPEG)
    ///   - size: Canvas size for export
    ///   - completion: Completion handler with success/failure result
    func exportDrawing(
        _ drawingState: DrawingState,
        format: ExportFormat,
        size: CGSize,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try self.createExportFile(
                    drawingState: drawingState,
                    format: format,
                    size: size
                )
                
                DispatchQueue.main.async {
                    completion(.success(url))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Show save panel and export drawing
    /// - Parameters:
    ///   - drawingState: Current drawing state
    ///   - format: Export format
    ///   - size: Canvas size
    func showExportPanel(
        for drawingState: DrawingState,
        format: ExportFormat,
        size: CGSize
    ) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Annotations"
        savePanel.nameFieldStringValue = "Pointly Annotations.\(format.fileExtension)"
        savePanel.allowedContentTypes = [format.utType]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            self.exportDrawing(drawingState, format: format, size: size) { result in
                switch result {
                case .success(let tempURL):
                    do {
                        // Move from temp location to user-selected location
                        if FileManager.default.fileExists(atPath: url.path) {
                            try FileManager.default.removeItem(at: url)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: url)
                        
                        // Show success notification
                        self.showNotification(
                            title: "Export Successful",
                            message: "Annotations saved to \(url.lastPathComponent)"
                        )
                        
                        // Reveal in Finder
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                        
                    } catch {
                        self.showErrorAlert("Export failed: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    self.showErrorAlert("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createExportFile(
        drawingState: DrawingState,
        format: ExportFormat,
        size: CGSize
    ) throws -> URL {
        // Create a temporary directory for export
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "pointly-export-\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        switch format {
        case .png, .jpeg:
            try createImageFile(drawingState: drawingState, format: format, size: size, url: tempURL)
        case .pdf:
            try createPDFFile(drawingState: drawingState, size: size, url: tempURL)
        }
        
        return tempURL
    }
    
    private func createImageFile(
        drawingState: DrawingState,
        format: ExportFormat,
        size: CGSize,
        url: URL
    ) throws {
        // Create image representation
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let rep = rep else {
            throw ExportError.imageCreationFailed
        }
        
        // Create graphics context
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        // Clear background (white for JPEG, transparent for PNG)
        if format == .jpeg {
            NSColor.white.setFill()
        } else {
            NSColor.clear.setFill()
        }
        NSRect(origin: .zero, size: size).fill()
        
        // Draw all elements
        drawElements(drawingState.elements, in: NSRect(origin: .zero, size: size))
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Save to file
        let imageType: NSBitmapImageRep.FileType = format == .png ? .png : .jpeg
        guard let data = rep.representation(using: imageType, properties: [:]) else {
            throw ExportError.imageEncodingFailed
        }
        
        try data.write(to: url)
    }
    
    private func createPDFFile(
        drawingState: DrawingState,
        size: CGSize,
        url: URL
    ) throws {
        // Create PDF context
        guard let pdfContext = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw ExportError.pdfCreationFailed
        }
        
        let mediaBox = CGRect(origin: .zero, size: size)
        pdfContext.beginPDFPage(nil)
        
        // Convert to NSGraphicsContext for easier drawing
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        // Draw all elements
        drawElements(drawingState.elements, in: mediaBox)
        
        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }
    
    private func drawElements(_ elements: [DrawingElement], in rect: NSRect) {
        for element in elements {
            drawElement(element, in: rect)
        }
    }
    
    private func drawElement(_ element: DrawingElement, in rect: NSRect) {
        guard !element.points.isEmpty else { return }
        
        // Convert SwiftUI Color to NSColor
        let nsColor = NSColor(element.color)
        nsColor.withAlphaComponent(element.opacity).setStroke()
        
        let path = NSBezierPath()
        path.lineWidth = element.thickness
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        switch element.tool {
        case .pen, .highlighter:
            if element.points.count == 1 {
                // Single point - draw as circle
                let point = element.points[0]
                let rect = NSRect(
                    x: point.x - element.thickness / 2,
                    y: point.y - element.thickness / 2,
                    width: element.thickness,
                    height: element.thickness
                )
                path.appendOval(in: rect)
                path.fill()
            } else {
                // Multiple points - draw as path
                path.move(to: element.points[0])
                for point in element.points.dropFirst() {
                    path.line(to: point)
                }
                path.stroke()
            }
            
        case .rectangle:
            if element.points.count >= 2 {
                let start = element.points[0]
                let end = element.points.last!
                let rect = NSRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                path.appendRect(rect)
                path.stroke()
            }
            
        case .ellipse:
            if element.points.count >= 2 {
                let start = element.points[0]
                let end = element.points.last!
                let rect = NSRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                path.appendOval(in: rect)
                path.stroke()
            }
            
        case .line, .arrow:
            if element.points.count >= 2 {
                let start = element.points[0]
                let end = element.points.last!
                path.move(to: start)
                path.line(to: end)
                path.stroke()
                
                if element.tool == .arrow {
                    // Draw arrow head
                    drawArrowHead(from: start, to: end, thickness: element.thickness)
                }
            }
            
        default:
            break
        }
    }
    
    private func drawArrowHead(from start: CGPoint, to end: CGPoint, thickness: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength = thickness * 3
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPath = NSBezierPath()
        arrowPath.lineWidth = thickness
        arrowPath.lineCapStyle = .round
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        arrowPath.move(to: end)
        arrowPath.line(to: point1)
        arrowPath.move(to: end)
        arrowPath.line(to: point2)
        arrowPath.stroke()
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func showErrorAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Export Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

// MARK: - Export Errors
enum ExportError: LocalizedError {
    case imageCreationFailed
    case imageEncodingFailed
    case pdfCreationFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .imageCreationFailed:
            return "Failed to create image representation"
        case .imageEncodingFailed:
            return "Failed to encode image data"
        case .pdfCreationFailed:
            return "Failed to create PDF document"
        case .fileWriteFailed:
            return "Failed to write file to disk"
        }
    }
}
