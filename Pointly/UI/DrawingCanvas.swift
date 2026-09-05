import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

private let blurCIContext = CIContext(options: [.useSoftwareRenderer: false])

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

    // Any transient (self-fading) element OR a live laser cursor needs the animation timeline.
    private var hasLaserElements: Bool {
        state.liveLaserPoint != nil || visibleElements.contains { !$0.tool.isPersistent }
    }

    var body: some View {
        // TimelineView is only used when animated AND laser elements exist.
        // For snapshot rendering (animated = false) or when no laser is active,
        // use a plain Canvas — avoids TimelineView overhead and the opaque-type
        // resolution issues that break ImageRenderer.
        if animated && hasLaserElements {
            // The Canvas MUST consume timeline.date — SwiftUI otherwise sees an
            // unchanged view on ticks with no state changes and skips the
            // redraw, freezing the trail the moment the cursor stops moving.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    for element in visibleElements { drawElement(element, in: context, size: size) }
                    // Live cursor trail is display-scoped: points are window-
                    // local, so without the check it mirrors onto every screen.
                    if let lp = state.liveLaserPoint,
                       displayID == nil || state.liveLaserDisplayID == displayID {
                        if state.selectedTool == .laserPointer {
                            drawLiveLaserTrail(now: timeline.date, in: context)
                            drawLiveLaserDot(at: lp, now: timeline.date,
                                             color: state.selectedColor,
                                             thick: state.strokeThickness, in: context)
                        } else {
                            drawLiveBrushRing(at: lp, in: context)
                        }
                    }
                }
                .id(timeline.date)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        } else {
            Canvas { context, size in
                for element in visibleElements { drawElement(element, in: context, size: size) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }
    
    private func drawElement(_ element: DrawingElement, in context: GraphicsContext, size: CGSize = .zero) {
        guard !element.points.isEmpty else { return }
        
        switch element.tool {
        case .pen, .highlighter:
            drawStroke(element, in: context)
        case .stepBadge:
            drawStepBadge(element, in: context)
        case .textCallout:
            drawCallout(element, in: context)
        case .eraser:
            // Eraser is handled by removing elements, no drawing needed
            break
        case .marker:
            drawMarker(element, in: context)
        case .blurBrush:
            drawBlurBrush(element, in: context, size: size)
        case .laserPointer:
            break  // live-rendered from liveLaserTrail/Point, never from elements
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
        // Slightly rounded corners — matches the brand's soft-rect language
        let radius = max(4, element.thickness * 1.2)
        let path = Path(roundedRect: rect, cornerRadius: min(radius, min(rect.width, rect.height) / 2))
        if element.isFilled {
            context.fill(path, with: .color(element.color.opacity(element.opacity * 0.3)))
        }
        strokeWithGlow(path, color: element.color, thickness: element.thickness, in: context)
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
        strokeWithGlow(Path(ellipseIn: rect), color: element.color, thickness: element.thickness, in: context)
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
        strokeWithGlow(path, color: element.color, thickness: element.thickness, in: context)
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
        strokeWithGlow(path, color: element.color, thickness: element.thickness, in: context)
    }

    // Callout: leader line from the target to a rounded label box with text.
    private func drawCallout(_ element: DrawingElement, in context: GraphicsContext) {
        guard element.points.count >= 2 else { return }
        let target = element.points[0]
        let box = DrawingElement.calloutBox(origin: element.points[1],
                                            text: element.text ?? "", thickness: element.thickness)
        let color = element.color

        // Leader line from the target to the nearest point on the box edge
        let anchor = CGPoint(x: min(max(target.x, box.minX), box.maxX),
                             y: min(max(target.y, box.minY), box.maxY))
        var leader = Path()
        leader.move(to: target)
        leader.addLine(to: anchor)
        context.stroke(leader, with: .color(color.opacity(0.9)),
                       style: StrokeStyle(lineWidth: max(1.5, element.thickness * 0.6), lineCap: .round))
        // Dot on the target
        let dot = 3 + element.thickness * 0.5
        context.fill(Path(ellipseIn: CGRect(x: target.x - dot, y: target.y - dot,
                                            width: dot * 2, height: dot * 2)),
                     with: .color(color))

        // Rounded box: dark glass fill so text reads on any background, brand border
        let boxPath = Path(roundedRect: box, cornerRadius: 8)
        context.fill(boxPath, with: .color(Color(red: 0.03, green: 0.03, blue: 0.07).opacity(0.9)))
        context.stroke(boxPath, with: .color(color), style: StrokeStyle(lineWidth: 1.5))

        let label = Text(element.text ?? "")
            .font(.system(size: DrawingElement.calloutFontSize(for: element.thickness), weight: .semibold))
            .foregroundColor(.white)
        context.draw(label, at: CGPoint(x: box.midX, y: box.midY), anchor: .center)
    }

    // Auto-numbered step badge: colored disc + soft halo + white bold number
    private func drawStepBadge(_ element: DrawingElement, in context: GraphicsContext) {
        guard let center = element.points.first else { return }
        let r = DrawingElement.stepBadgeRadius(for: element.thickness)

        let halo = Path(ellipseIn: CGRect(x: center.x - r * 1.4, y: center.y - r * 1.4,
                                          width: r * 2.8, height: r * 2.8))
        context.fill(halo, with: .color(element.color.opacity(0.20)))

        let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                          width: r * 2, height: r * 2))
        context.fill(disc, with: .color(element.color))
        context.stroke(disc, with: .color(.white.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 1.5))

        let label = Text(element.text ?? "1")
            .font(.system(size: r * 1.05, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        context.draw(label, at: center, anchor: .center)
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
        let headLength: CGFloat = min(max(20, element.thickness * 6), max(12, dist * 0.55))
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
        let thick = element.thickness * 1.4
        let color = element.color

        let path: Path
        if element.points.count == 1, let pt = element.points.first {
            // Single tap → square stamp
            let r = thick / 2
            path = Path(CGRect(x: pt.x - r, y: pt.y - r, width: thick, height: thick))
        } else {
            guard element.points.count > 1 else { return }
            var p = Path()
            p.move(to: element.points[0])
            element.points.dropFirst().forEach { p.addLine(to: $0) }
            path = p
        }

        // Outer bleed — ink feathers slightly beyond the stroke edge like on paper
        context.stroke(path,
                       with: .color(color.opacity(0.10)),
                       style: StrokeStyle(lineWidth: thick * 1.55, lineCap: .square, lineJoin: .round))

        // Core ink — flat square tip is the key marker characteristic;
        // semi-transparent so crossing strokes darken naturally
        context.stroke(path,
                       with: .color(color.opacity(element.opacity)),
                       style: StrokeStyle(lineWidth: thick, lineCap: .square, lineJoin: .round))

        // Center sheen — faint highlight along the ink surface
        context.stroke(path,
                       with: .color(color.opacity(0.07)),
                       style: StrokeStyle(lineWidth: thick * 0.28, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Blur brush
    // CIPixellate is expensive on a full-screen CGImage, so we cache the result
    // keyed by element ID. Each element gets computed once and reused every frame.
    private static var pixelateCache: [UUID: CGImage] = [:]

    private func drawBlurBrush(_ element: DrawingElement, in context: GraphicsContext, size: CGSize) {
        guard let bgCapture = element.backgroundCapture, size != .zero else {
            drawBlurBrushFallback(element, in: context)
            return
        }

        // Build filled clip path from the stroke shape
        let clipPath: Path
        if element.points.count == 1, let pt = element.points.first {
            let r = element.thickness
            clipPath = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
        } else {
            var p = Path()
            p.move(to: element.points[0])
            element.points.dropFirst().forEach { p.addLine(to: $0) }
            clipPath = p.strokedPath(StrokeStyle(lineWidth: element.thickness * 2,
                                                  lineCap: .round, lineJoin: .round))
        }

        // Retrieve or compute pixelated image — only runs once per element
        let blurredCG: CGImage
        if let cached = DrawingCanvas.pixelateCache[element.id] {
            blurredCG = cached
        } else {
            let ci = CIImage(cgImage: bgCapture)
            let pixelated = ci.applyingFilter("CIPixellate", parameters: ["inputScale": 24])
            guard let rendered = blurCIContext.createCGImage(pixelated, from: ci.extent) else {
                drawBlurBrushFallback(element, in: context)
                return
            }
            DrawingCanvas.pixelateCache[element.id] = rendered
            blurredCG = rendered
        }

        // Clip to stroke shape in an isolated layer so it doesn't affect outer context
        context.drawLayer { layerCtx in
            layerCtx.clip(to: clipPath)
            let scale = size.width > 0 ? CGFloat(bgCapture.width) / size.width : 2.0
            layerCtx.draw(Image(decorative: blurredCG, scale: scale),
                          in: CGRect(origin: .zero, size: size))
        }
    }

    private func drawBlurBrushFallback(_ element: DrawingElement, in context: GraphicsContext) {
        let blurRadius = element.blurRadius ?? element.thickness * 2
        for i in 0..<5 {
            let t = CGFloat(i) / 5
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
                context.stroke(path, with: .color(element.color.opacity(alpha)),
                    style: StrokeStyle(lineWidth: radius * 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - Laser pointer
    //
    // Fully live-rendered from DrawingState.liveLaserPoint/Trail — the laser
    // never creates drawing elements. The dot is the cursor, always full
    // brightness; the trail is residual light from movement (hover or drag),
    // each segment fading by its point's AGE so only the last ~quarter second
    // glows: vivid at the cursor, transparent behind. Stop moving and the
    // trail evaporates, leaving just the bright dot.

    /// How long a trail point stays visible after capture.
    private static let laserTrailLife: TimeInterval = 0.26

    /// Push the user's color to full saturation + brightness so it reads as
    /// emitted laser light (default brand salmon → intense laser red), plus a
    /// pale near-white tint for the core falloff.
    private func laserPalette(_ color: Color) -> (vivid: Color, pale: Color) {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? .systemRed
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Color(hue: h, saturation: min(1.0, s * 1.5 + 0.15), brightness: 1.0),
                Color(hue: h, saturation: min(1.0, s * 0.4), brightness: 1.0))
    }

    /// The fading light trail behind the moving dot — rendered from the live
    /// buffer, so it appears on plain mouse movement, not just click-drags.
    private func drawLiveLaserTrail(now: Date, in context: GraphicsContext) {
        let trail = state.liveLaserTrail
        guard trail.count > 1 else { return }

        let (vivid, _) = laserPalette(state.selectedColor)
        let thick = state.strokeThickness

        // The instant movement stops, collapse the whole trail fast (~150ms).
        // Residual light belongs behind a MOVING laser — a parked dot should
        // stand alone, not keep a glowing tail.
        let idle     = now.timeIntervalSince(trail.last!.time)
        let stopFade = max(0.0, 1.0 - max(0.0, idle - 0.05) / 0.10)
        guard stopFade > 0.001 else { return }

        // Collect slices still within the trail lifetime, newest first.
        // Bezier midpoint smoothing (midpoint → midpoint, sample as control):
        // straight lines between fast, widely-spaced hover samples show hard
        // polygon corners; curved slices keep the tangents continuous.
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        var slices: [(path: Path, energy: Double, width: CGFloat)] = []
        for i in stride(from: trail.count - 1, through: 1, by: -1) {
            let age = now.timeIntervalSince(trail[i].time)
            if age > Self.laserTrailLife { break }
            let k = 1.0 - age / Self.laserTrailLife    // 1 at cursor → 0 at tail
            var p = Path()
            p.move(to: mid(trail[i - 1].point, trail[i].point))
            if i == trail.count - 1 {
                p.addLine(to: trail[i].point)          // head stub up to the dot
            } else {
                p.addQuadCurve(to: mid(trail[i].point, trail[i + 1].point),
                               control: trail[i].point)
            }
            slices.append((p, pow(k, 1.6),
                           max(0.8, thick * 0.7) * CGFloat(0.3 + 0.7 * k)))
        }
        guard !slices.isEmpty else { return }

        // Pass 1 — soft residual glow around the streak
        for s in slices {
            context.stroke(s.path, with: .color(vivid.opacity(s.energy * stopFade * 0.14)),
                style: StrokeStyle(lineWidth: s.width * 3.6, lineCap: .round))
        }
        // Pass 2 — thin vivid streak, brightest right behind the cursor
        for s in slices {
            context.stroke(s.path, with: .color(vivid.opacity(s.energy * stopFade * 0.85)),
                style: StrokeStyle(lineWidth: s.width, lineCap: .round))
        }
    }

    // MARK: - Brush ghost trail
    //
    // Same live-trail idea as the laser, but brush-styled: soft translucent
    // discs at the brush's true footprint drift behind the ring cursor and
    // dissolve — bokeh-like residual paint, not a streak of light.

    /// Visual radius each brush actually paints at (matches the ring cursor).
    private var brushGhostRadius: CGFloat {
        switch state.selectedTool {
        case .highlighter: return state.strokeThickness / 2
        case .marker:      return state.strokeThickness * 0.7 + 1.2
        case .blurBrush:   return state.strokeThickness * 2
        default:           return state.strokeThickness / 2
        }
    }

    private func drawLiveBrushRing(at point: CGPoint, in context: GraphicsContext) {
        let r = max(4, brushGhostRadius)
        let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect),
                     with: .color(state.selectedColor.opacity(0.18)))
        context.stroke(Path(ellipseIn: rect),
                       with: .color(state.selectedColor.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1.5))
    }

    private func drawLiveBrushTrail(now: Date, in context: GraphicsContext) {
        let trail = state.liveLaserTrail
        guard trail.count > 1 else { return }

        let life: TimeInterval = 0.4
        // Collapse quickly once movement stops — same rule as the laser.
        let idle     = now.timeIntervalSince(trail.last!.time)
        let stopFade = max(0.0, 1.0 - max(0.0, idle - 0.05) / 0.12)
        guard stopFade > 0.001 else { return }

        let r = max(4, brushGhostRadius)
        let color = state.selectedColor

        // Space the discs ~0.7 radii apart (newest first) so they read as
        // distinct bokeh circles instead of piling into an opaque blob.
        var lastKept: CGPoint? = nil
        for entry in trail.dropLast().reversed() {
            let age = now.timeIntervalSince(entry.time)
            if age > life { break }
            if let prev = lastKept,
               hypot(entry.point.x - prev.x, entry.point.y - prev.y) < r * 0.7 {
                continue
            }
            lastKept = entry.point
            let k     = 1.0 - age / life
            let alpha = pow(k, 1.7) * 0.18 * stopFade
            let rad   = r * (0.5 + 0.5 * k)
            context.fill(
                Path(ellipseIn: CGRect(x: entry.point.x - rad, y: entry.point.y - rad,
                                       width: rad * 2, height: rad * 2)),
                with: .color(color.opacity(alpha)))
        }
    }

    /// The laser dot: tiny white-hot source, vivid saturated falloff, soft
    /// bloom. Radial gradients only — the eye perceives light, never a circle.
    private func drawLiveLaserDot(at tip: CGPoint, now: Date, color: Color,
                                  thick: CGFloat, in context: GraphicsContext) {
        let (vivid, pale) = laserPalette(color)
        let t = now.timeIntervalSinceReferenceDate
        // Irregular shimmer: three incommensurate frequencies, tiny amplitude —
        // alive, but never reads as a rhythmic pulse.
        let shimmer = 1.0 + 0.045 * sin(t * 13.7)
                          + 0.028 * sin(t * 29.3 + 1.7)
                          + 0.018 * sin(t * 47.9 + 0.4)

        // Tiny source; the bloom sells the perceived size.
        let src = max(2.2, thick * 0.6)

        func disc(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r, width: r * 2, height: r * 2))
        }

        // Layer 1 — outer ambience: an extremely subtle wash of light
        let ambR = src * 13
        context.fill(disc(ambR), with: .radialGradient(
            Gradient(stops: [
                .init(color: vivid.opacity(0.07), location: 0),
                .init(color: vivid.opacity(0.025), location: 0.45),
                .init(color: vivid.opacity(0), location: 1)]),
            center: tip, startRadius: 0, endRadius: ambR))

        // Layer 2 — bloom: the emitted light around the source
        let bloomR = src * 6 * CGFloat(0.96 + 0.04 * shimmer)
        context.fill(disc(bloomR), with: .radialGradient(
            Gradient(stops: [
                .init(color: vivid.opacity(0.42 * shimmer), location: 0),
                .init(color: vivid.opacity(0.16), location: 0.4),
                .init(color: vivid.opacity(0), location: 1)]),
            center: tip, startRadius: 0, endRadius: bloomR))

        // Layer 3 — the source itself: white-hot → pale → vivid → transparent
        // in one continuous gradient, so there is no visible edge anywhere.
        let coreR = src * 2.3 * CGFloat(shimmer)
        context.fill(disc(coreR), with: .radialGradient(
            Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white.opacity(0.98), location: 0.16),
                .init(color: pale, location: 0.3),
                .init(color: vivid.opacity(0.98), location: 0.52),
                .init(color: vivid.opacity(0.4), location: 0.78),
                .init(color: vivid.opacity(0), location: 1)]),
            center: tip, startRadius: 0, endRadius: coreR))
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

