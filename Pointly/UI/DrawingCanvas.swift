import SwiftUI

/// Canvas view that renders all drawing elements
struct DrawingCanvas: View {
    @ObservedObject var state: DrawingState
    /// Display this canvas belongs to. Element points are window-local, so
    /// each canvas draws only its own display's elements (nil = draw all).
    var displayID: CGDirectDisplayID? = nil
    /// Set to false for static snapshot rendering (e.g. ImageRenderer) to avoid
    /// TimelineView's animation infrastructure which doesn't work in that context.
    var animated: Bool = true

    private var visibleElements: [DrawingElement] {
        guard let displayID else { return state.elements }
        return state.elements.filter { $0.displayID == nil || $0.displayID == displayID }
    }

    private var hasLaserElements: Bool {
        visibleElements.contains { $0.tool == .laserPointer }
    }

    var body: some View {
        // TimelineView is only used when animated AND laser elements exist.
        // For snapshot rendering (animated = false) or when no laser is active,
        // use a plain Canvas — avoids TimelineView overhead and the opaque-type
        // resolution issues that break ImageRenderer.
        if animated && hasLaserElements {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
                Canvas { context, size in
                    for element in visibleElements { drawElement(element, in: context) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        } else {
            Canvas { context, size in
                for element in visibleElements { drawElement(element, in: context) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
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
        case .dotPen:
            drawDotPen(element, in: context)
        case .cutMove:
            break  // handled by selection UI in OverlayView
        case .rectangle:
            drawRectangle(element, in: context)
        case .ellipse:
            drawEllipse(element, in: context)
        case .triangle:
            drawTriangle(element, in: context)
        case .diamond:
            drawDiamond(element, in: context)
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

    private func drawTriangle(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        let start = element.points[0], end = element.points.last!
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        if element.isFilled {
            context.fill(path, with: .color(element.color.opacity(element.opacity * 0.3)))
        }
        context.stroke(path, with: .color(element.color), style: StrokeStyle(lineWidth: element.thickness, lineJoin: .round))
    }

    private func drawDiamond(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        let start = element.points[0], end = element.points.last!
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        if element.isFilled {
            context.fill(path, with: .color(element.color.opacity(element.opacity * 0.3)))
        }
        context.stroke(path, with: .color(element.color), style: StrokeStyle(lineWidth: element.thickness, lineJoin: .round))
    }

    // Soft two-layer halo in the element's own color under the core stroke —
    // the Pointly glow, kept subtle (single color, no gradient).
    private func strokeWithGlow(_ path: Path, color: Color, thickness: CGFloat,
                                in context: GraphicsContext) {
        context.stroke(path, with: .color(color.opacity(0.16)),
                       style: StrokeStyle(lineWidth: thickness * 3.2, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(color.opacity(0.32)),
                       style: StrokeStyle(lineWidth: thickness * 1.9, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
    }

    private func drawLine(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }

        let startPoint = element.points[0]
        let endPoint = element.points.last!

        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        strokeWithGlow(path, color: element.color, thickness: element.thickness, in: context)
    }

    private func drawArrow(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }

        let startPoint = element.points[0]
        let endPoint = element.points.last!
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let dist = hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)

        // Solid triangular head — bigger and sleeker than the old open V.
        // Clamped so a short arrow doesn't become all head.
        let headLength: CGFloat = min(max(16, element.thickness * 4.5), max(10, dist * 0.5))
        let headAngle: CGFloat = .pi / 7   // ~26° — sleek point

        let tip = endPoint
        let p1 = CGPoint(x: tip.x - headLength * cos(angle - headAngle),
                         y: tip.y - headLength * sin(angle - headAngle))
        let p2 = CGPoint(x: tip.x - headLength * cos(angle + headAngle),
                         y: tip.y - headLength * sin(angle + headAngle))
        // Shaft stops at the head's base so it doesn't poke through the tip
        let base = CGPoint(x: tip.x - headLength * 0.8 * cos(angle),
                           y: tip.y - headLength * 0.8 * sin(angle))

        var shaft = Path()
        shaft.move(to: startPoint)
        shaft.addLine(to: base)

        var head = Path()
        head.move(to: tip)
        head.addLine(to: p1)
        head.addLine(to: p2)
        head.closeSubpath()

        strokeWithGlow(shaft, color: element.color, thickness: element.thickness, in: context)
        // Halo around the head, then the solid fill
        context.stroke(head, with: .color(element.color.opacity(0.25)),
                       style: StrokeStyle(lineWidth: element.thickness * 1.6, lineJoin: .round))
        context.fill(head, with: .color(element.color))
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

    // MARK: - Dot Pen: dots spaced along the path using a dashed round-capped stroke
    private func drawDotPen(_ element: DrawingElement, in context: GraphicsContext) {
        guard !element.points.isEmpty else { return }
        let spacing = max(element.thickness * 4.0, 10)

        if element.points.count == 1, let pt = element.points.first {
            let r = element.thickness / 2
            context.fill(
                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: element.thickness, height: element.thickness)),
                with: .color(element.color.opacity(element.opacity))
            )
            return
        }

        var path = Path()
        path.move(to: element.points[0])
        for i in 1..<element.points.count {
            let cur = element.points[i]
            if i == element.points.count - 1 {
                path.addLine(to: cur)
            } else {
                let next = element.points[i + 1]
                let mid = CGPoint(x: (cur.x + next.x) / 2, y: (cur.y + next.y) / 2)
                path.addQuadCurve(to: mid, control: cur)
            }
        }

        context.stroke(
            path,
            with: .color(element.color.opacity(element.opacity)),
            style: StrokeStyle(
                lineWidth: element.thickness,
                lineCap: .round,
                lineJoin: .round,
                dash: [0, spacing]
            )
        )
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

