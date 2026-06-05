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
        
        context.stroke(
            Path(rect),
            with: .color(element.color),
            style: StrokeStyle(lineWidth: element.thickness)
        )
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
        
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(element.color),
            style: StrokeStyle(lineWidth: element.thickness)
        )
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
    
    private func drawText(_ element: DrawingElement, in context: GraphicsContext) {
        // TODO: Implement text rendering
        // This would require additional state for text content and font properties
        // For now, we'll draw a placeholder
        guard let point = element.points.first else { return }
        
        let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
        context.stroke(
            Path(rect),
            with: .color(element.color),
            style: StrokeStyle(lineWidth: 1)
        )
    }
}

#Preview {
    let state = DrawingState()
    return DrawingCanvas(state: state)
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.1))
}
