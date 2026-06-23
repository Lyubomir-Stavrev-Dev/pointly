import SwiftUI

/// Canvas view that renders all drawing elements
struct DrawingCanvas: View {
    @ObservedObject var state: DrawingState
    
    var body: some View {
        Canvas { context, size in
            // Render all drawing elements
            for element in state.elements {
                drawElement(element, in: context)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Let touches pass through to parent
    }
    
    private func drawElement(_ element: DrawingElement, in context: GraphicsContext) {
        guard !element.points.isEmpty else { return }
        
        switch element.tool {
        case .pen, .highlighter:
            drawStroke(element, in: context)
        case .eraser:
            // Eraser is handled by removing elements, no drawing needed
            break
        case .marker:
            drawMarker(element, in: context)
        case .blurBrush:
            drawBlurBrush(element, in: context)
        case .laserPointer:
            drawLaserPointer(element, in: context)
        case .rectangle:
            drawRectangle(element, in: context)
        case .ellipse:
            drawEllipse(element, in: context)
        case .arrow:
            drawArrow(element, in: context)
        case .line:
            drawLine(element, in: context)
        case .text:
            drawText(element, in: context)
        default:
            break
        }
    }
    
    private func drawStroke(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count > 1 else {
            // Single point - draw as circle
            if let point = element.points.first {
                let rect = CGRect(
                    x: point.x - element.thickness / 2,
                    y: point.y - element.thickness / 2,
                    width: element.thickness,
                    height: element.thickness
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(element.color.opacity(element.opacity))
                )
            }
            return
        }
        
        // Create smooth path through points
        var path = Path()
        path.move(to: element.points[0])
        
        // Use quadratic curves for smooth drawing
        for i in 1..<element.points.count {
            let currentPoint = element.points[i]
            if i == element.points.count - 1 {
                path.addLine(to: currentPoint)
            } else {
                let nextPoint = element.points[i + 1]
                let controlPoint = CGPoint(
                    x: (currentPoint.x + nextPoint.x) / 2,
                    y: (currentPoint.y + nextPoint.y) / 2
                )
                path.addQuadCurve(to: controlPoint, control: currentPoint)
            }
        }
        
        // Apply stroke styling
        context.stroke(
            path,
            with: .color(element.color.opacity(element.opacity)),
            style: StrokeStyle(
                lineWidth: element.thickness,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
    
    private func drawRectangle(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        let startPoint = element.points[0]
        let endPoint = element.points.last!
        let rect = CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
        if element.isFilled {
            context.fill(Path(rect), with: .color(element.color.opacity(element.opacity * 0.3)))
        }
        context.stroke(Path(rect), with: .color(element.color), style: StrokeStyle(lineWidth: element.thickness))
    }

    private func drawEllipse(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        let startPoint = element.points[0]
        let endPoint = element.points.last!
        let rect = CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
        if element.isFilled {
            context.fill(Path(ellipseIn: rect), with: .color(element.color.opacity(element.opacity * 0.3)))
        }
        context.stroke(Path(ellipseIn: rect), with: .color(element.color), style: StrokeStyle(lineWidth: element.thickness))
    }
    
    private func drawLine(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        
        let startPoint = element.points[0]
        let endPoint = element.points.last!
        
        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        context.stroke(
            path,
            with: .color(element.color),
            style: StrokeStyle(
                lineWidth: element.thickness,
                lineCap: .round
            )
        )
    }
    
    private func drawArrow(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        
        let startPoint = element.points[0]
        let endPoint = element.points.last!
        
        // Draw main line
        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        // Calculate arrow head
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength: CGFloat = element.thickness * 3
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees
        
        let arrowPoint1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let arrowPoint2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )
        
        // Add arrow head lines
        path.move(to: endPoint)
        path.addLine(to: arrowPoint1)
        path.move(to: endPoint)
        path.addLine(to: arrowPoint2)
        
        context.stroke(
            path,
            with: .color(element.color),
            style: StrokeStyle(
                lineWidth: element.thickness,
                lineCap: .round
            )
        )
    }
    
    // MARK: - Marker: multiple overlapping strokes at varying offsets create a textured look
    private func drawMarker(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count > 1 else { return }
        let offsets: [(CGFloat, CGFloat, Double)] = [
            ( 0,  0,   0.55),
            ( 1.2, 0.5, 0.30),
            (-0.8, 1.0, 0.25),
            ( 0.5,-1.2, 0.20),
        ]
        for (dx, dy, alpha) in offsets {
            var path = Path()
            path.move(to: element.points[0].offset(dx: dx, dy: dy))
            for i in 1..<element.points.count {
                path.addLine(to: element.points[i].offset(dx: dx, dy: dy))
            }
            context.stroke(path,
                with: .color(element.color.opacity(alpha)),
                style: StrokeStyle(lineWidth: element.thickness * 1.4, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Blur brush: concentric semi-transparent rings simulate a soft glow/blur
    private func drawBlurBrush(_ element: DrawingElement, in context: GraphicsContext) {
        let blurRadius = element.blurRadius ?? element.thickness * 2
        let rings = 5
        for i in 0..<rings {
            let t = CGFloat(i) / CGFloat(rings)
            let radius = blurRadius * (0.3 + t * 0.7)
            let alpha  = element.opacity * Double(1.0 - t) * 0.35
            var path = Path()
            if element.points.count == 1, let pt = element.points.first {
                path.addEllipse(in: CGRect(x: pt.x - radius, y: pt.y - radius,
                                           width: radius * 2, height: radius * 2))
                context.fill(path, with: .color(element.color.opacity(alpha)))
            } else {
                path.move(to: element.points[0])
                for pt in element.points.dropFirst() { path.addLine(to: pt) }
                context.stroke(path,
                    with: .color(element.color.opacity(alpha)),
                    style: StrokeStyle(lineWidth: radius * 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - Laser pointer: bright core + wide glow halo, fades over time
    private func drawLaserPointer(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count > 1 else {
            if let pt = element.points.first {
                let r = element.thickness * 4
                let opacity = element.currentOpacity
                // outer glow
                context.fill(Path(ellipseIn: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)),
                             with: .color(element.color.opacity(opacity * 0.25)))
                // bright core
                let cr = element.thickness
                context.fill(Path(ellipseIn: CGRect(x: pt.x-cr, y: pt.y-cr, width: cr*2, height: cr*2)),
                             with: .color(Color.white.opacity(opacity * 0.9)))
            }
            return
        }
        let opacity = element.currentOpacity
        // Wide outer glow
        var glowPath = Path()
        glowPath.move(to: element.points[0])
        for pt in element.points.dropFirst() { glowPath.addLine(to: pt) }
        context.stroke(glowPath,
            with: .color(element.color.opacity(opacity * 0.20)),
            style: StrokeStyle(lineWidth: element.thickness * 8, lineCap: .round, lineJoin: .round))
        // Medium halo
        context.stroke(glowPath,
            with: .color(element.color.opacity(opacity * 0.40)),
            style: StrokeStyle(lineWidth: element.thickness * 4, lineCap: .round, lineJoin: .round))
        // Bright core
        context.stroke(glowPath,
            with: .color(Color.white.opacity(opacity * 0.85)),
            style: StrokeStyle(lineWidth: element.thickness * 0.8, lineCap: .round, lineJoin: .round))
    }

    private func drawText(_ element: DrawingElement, in context: GraphicsContext) {
        guard let point = element.points.first,
              let text = element.text, !text.isEmpty else { return }
        let fontSize = max(14, element.thickness * 4)
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(element.color.opacity(element.currentOpacity))
        )
        context.draw(resolved, at: point, anchor: .topLeading)
    }
}

// MARK: - Helpers
private extension CGPoint {
    func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}

#Preview {
    let state = DrawingState()
    return DrawingCanvas(state: state)
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.1))
}
