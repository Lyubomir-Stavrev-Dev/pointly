import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

class ExportManager: ObservableObject {

    enum ExportFormat: String, CaseIterable {
        case png = "png"
        case pdf = "pdf"
        case jpeg = "jpeg"

        var displayName: String {
            switch self {
            case .png:  return "PNG Image"
            case .pdf:  return "PDF Document"
            case .jpeg: return "JPEG Image"
            }
        }

        var fileExtension: String { rawValue }

        var utType: UTType {
            switch self {
            case .png:  return .png
            case .pdf:  return .pdf
            case .jpeg: return .jpeg
            }
        }
    }

    // MARK: - Public API

    func showExportPanel(
        for drawingState: DrawingState,
        format: ExportFormat,
        size: CGSize
    ) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Annotations"
        savePanel.nameFieldStringValue = defaultFilename(for: format)
        savePanel.allowedContentTypes = [format.utType]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url, let self else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let tempURL = try self.createExportFile(drawingState: drawingState, format: format, size: size)

                    DispatchQueue.main.async {
                        do {
                            if FileManager.default.fileExists(atPath: url.path) {
                                try FileManager.default.removeItem(at: url)
                            }
                            try FileManager.default.moveItem(at: tempURL, to: url)

                            if UserDefaults.standard.object(forKey: "showExportNotification") as? Bool ?? true {
                                self.showNotification(title: "Export Successful",
                                                      message: "Saved to \(url.lastPathComponent)")
                            }
                            if UserDefaults.standard.object(forKey: "autoOpenExport") as? Bool ?? true {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        } catch {
                            self.showErrorAlert("Export failed: \(error.localizedDescription)")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showErrorAlert("Export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - File Creation

    private func createExportFile(
        drawingState: DrawingState,
        format: ExportFormat,
        size: CGSize
    ) throws -> URL {
        let fileName = "pointly-\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        switch format {
        case .png, .jpeg:
            try createImageFile(elements: drawingState.elements, format: format, size: size, url: tempURL)
        case .pdf:
            try createPDFFile(elements: drawingState.elements, size: size, url: tempURL)
        }
        return tempURL
    }

    private func createImageFile(
        elements: [DrawingElement],
        format: ExportFormat,
        size: CGSize,
        url: URL
    ) throws {
        guard let rep = NSBitmapImageRep(
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
        ) else { throw ExportError.imageCreationFailed }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        // Flip coordinate system: AppKit bitmap has origin at bottom-left,
        // but overlay uses top-left origin (SwiftUI/NSWindow default).
        if let cgCtx = NSGraphicsContext.current?.cgContext {
            cgCtx.translateBy(x: 0, y: size.height)
            cgCtx.scaleBy(x: 1, y: -1)
        }

        if format == .jpeg {
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
        }

        drawElements(elements, in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let quality = UserDefaults.standard.double(forKey: "exportQuality")
        let props: [NSBitmapImageRep.PropertyKey: Any] = format == .jpeg
            ? [.compressionFactor: quality > 0 ? quality : 0.9]
            : [:]
        let fileType: NSBitmapImageRep.FileType = format == .png ? .png : .jpeg
        guard let data = rep.representation(using: fileType, properties: props) else {
            throw ExportError.imageEncodingFailed
        }
        try data.write(to: url)
    }

    private func createPDFFile(elements: [DrawingElement], size: CGSize, url: URL) throws {
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw ExportError.pdfCreationFailed
        }

        pdfContext.beginPDFPage([kCGPDFContextMediaBox: NSValue(rect: NSRect(origin: .zero, size: size))] as CFDictionary)

        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        // Flip to match top-left origin
        pdfContext.translateBy(x: 0, y: size.height)
        pdfContext.scaleBy(x: 1, y: -1)

        drawElements(elements, in: NSRect(origin: .zero, size: size))

        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }

    // MARK: - Element Rendering

    private func drawElements(_ elements: [DrawingElement], in rect: NSRect) {
        for element in elements {
            drawElement(element, in: rect)
        }
    }

    private func drawElement(_ element: DrawingElement, in rect: NSRect) {
        guard !element.points.isEmpty else { return }
        let nsColor = NSColor(element.color)

        switch element.tool {
        case .pen, .highlighter:
            nsColor.withAlphaComponent(element.opacity).setStroke()
            let path = strokePath(for: element)
            path.lineWidth = element.thickness
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

        case .marker:
            drawMarker(element, color: nsColor)

        case .blurBrush:
            drawBlurBrush(element, color: nsColor)

        case .rectangle:
            guard element.points.count >= 2 else { return }
            let r = shapeRect(for: element)
            let path = NSBezierPath(rect: r)
            path.lineWidth = element.thickness
            if element.isFilled {
                nsColor.withAlphaComponent(element.opacity * 0.3).setFill()
                path.fill()
            }
            nsColor.withAlphaComponent(element.opacity).setStroke()
            path.stroke()

        case .ellipse:
            guard element.points.count >= 2 else { return }
            let r = shapeRect(for: element)
            let path = NSBezierPath(ovalIn: r)
            path.lineWidth = element.thickness
            if element.isFilled {
                nsColor.withAlphaComponent(element.opacity * 0.3).setFill()
                path.fill()
            }
            nsColor.withAlphaComponent(element.opacity).setStroke()
            path.stroke()

        case .line:
            guard element.points.count >= 2 else { return }
            nsColor.withAlphaComponent(element.opacity).setStroke()
            let path = NSBezierPath()
            path.lineWidth = element.thickness
            path.lineCapStyle = .round
            path.move(to: element.points[0])
            path.line(to: element.points.last!)
            path.stroke()

        case .arrow:
            guard element.points.count >= 2 else { return }
            nsColor.withAlphaComponent(element.opacity).setStroke()
            drawArrow(from: element.points[0], to: element.points.last!, thickness: element.thickness)

        case .text:
            drawText(element, color: nsColor)

        default:
            break
        }
    }

    // MARK: - Tool-specific Drawing

    private func drawMarker(_ element: DrawingElement, color: NSColor) {
        guard element.points.count > 1 else { return }
        let offsets: [(CGFloat, CGFloat, Double)] = [
            (0, 0, 0.55), (1.2, 0.5, 0.30), (-0.8, 1.0, 0.25), (0.5, -1.2, 0.20)
        ]
        for (dx, dy, alpha) in offsets {
            let path = NSBezierPath()
            path.lineWidth = element.thickness * 1.4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: element.points[0].x + dx, y: element.points[0].y + dy))
            for pt in element.points.dropFirst() {
                path.line(to: CGPoint(x: pt.x + dx, y: pt.y + dy))
            }
            color.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }
    }

    private func drawBlurBrush(_ element: DrawingElement, color: NSColor) {
        let blurRadius = element.blurRadius ?? element.thickness * 2
        let rings = 5
        for i in 0..<rings {
            let t = CGFloat(i) / CGFloat(rings)
            let radius = blurRadius * (0.3 + t * 0.7)
            let alpha = element.opacity * Double(1.0 - t) * 0.35
            color.withAlphaComponent(alpha).setFill()
            color.withAlphaComponent(alpha).setStroke()
            if element.points.count == 1, let pt = element.points.first {
                NSBezierPath(ovalIn: NSRect(x: pt.x - radius, y: pt.y - radius,
                                            width: radius * 2, height: radius * 2)).fill()
            } else if element.points.count > 1 {
                let path = NSBezierPath()
                path.lineWidth = radius * 2
                path.lineCapStyle = .round
                path.move(to: element.points[0])
                for pt in element.points.dropFirst() { path.line(to: pt) }
                path.stroke()
            }
        }
    }

    private func drawText(_ element: DrawingElement, color: NSColor) {
        guard let text = element.text, !text.isEmpty, let pt = element.points.first else { return }
        let fontSize = max(14, element.thickness * 4)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color.withAlphaComponent(element.opacity)
        ]
        text.draw(at: pt, withAttributes: attrs)
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, thickness: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = thickness
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLen = thickness * 3
        let arrowAngle: CGFloat = .pi / 6
        let p1 = CGPoint(x: end.x - arrowLen * cos(angle - arrowAngle),
                         y: end.y - arrowLen * sin(angle - arrowAngle))
        let p2 = CGPoint(x: end.x - arrowLen * cos(angle + arrowAngle),
                         y: end.y - arrowLen * sin(angle + arrowAngle))
        path.move(to: end); path.line(to: p1)
        path.move(to: end); path.line(to: p2)
        path.stroke()
    }

    private func strokePath(for element: DrawingElement) -> NSBezierPath {
        let path = NSBezierPath()
        guard element.points.count > 1 else {
            if let pt = element.points.first {
                let r = element.thickness / 2
                path.appendOval(in: NSRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
            }
            return path
        }
        path.move(to: element.points[0])
        for pt in element.points.dropFirst() { path.line(to: pt) }
        return path
    }

    private func shapeRect(for element: DrawingElement) -> NSRect {
        let start = element.points[0], end = element.points.last!
        return NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                      width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    // MARK: - Notifications

    private func defaultFilename(for format: ExportFormat) -> String {
        let useTimestamp = UserDefaults.standard.object(forKey: "includeTimestampInFilename") as? Bool ?? true
        if useTimestamp {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH-mm-ss"
            return "Pointly \(f.string(from: Date())).\(format.fileExtension)"
        }
        return "Pointly Annotations.\(format.fileExtension)"
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
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

// MARK: - Errors

enum ExportError: LocalizedError {
    case imageCreationFailed, imageEncodingFailed, pdfCreationFailed, fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .imageCreationFailed: return "Failed to create image representation"
        case .imageEncodingFailed: return "Failed to encode image data"
        case .pdfCreationFailed:   return "Failed to create PDF document"
        case .fileWriteFailed:     return "Failed to write file to disk"
        }
    }
}
