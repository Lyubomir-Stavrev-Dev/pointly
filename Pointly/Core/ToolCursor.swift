import AppKit

enum ToolCursor {
    private static var cache: [DrawingTool: NSCursor] = [:]

    // A 1×1 transparent cursor — the laser dot IS the cursor.
    static let transparent: NSCursor = {
        let img = NSImage(size: NSSize(width: 1, height: 1))
        return NSCursor(image: img, hotSpot: .zero)
    }()

    /// Thickness-aware variant: brush-like tools get a ring cursor showing the
    /// ACTUAL stroke footprint, centered where ink lands — an icon cursor there
    /// reads as "the brush is icon-sized" and then the stroke comes out thinner
    /// and offset to the hotspot.
    static func cursor(for tool: DrawingTool, thickness: CGFloat) -> NSCursor {
        return cursor(for: tool)
    }

    static func cursor(for tool: DrawingTool) -> NSCursor {
        switch tool {
        case .cursor:                                      return .arrow
        case .select:                                      return .arrow
        case .text:                                        return .iBeam
        case .laserPointer:                                return transparent
        case .rectangle, .ellipse, .triangle, .diamond,
             .arrow, .line:                                return shapeCursor()
        default: break
        }
        if let c = cache[tool] { return c }
        let c = build(tool)
        cache[tool] = c
        return c
    }

    // MARK: - SF-symbol tool cursors

    private static func build(_ tool: DrawingTool) -> NSCursor {
        let iconPt: CGFloat = 20
        let pad:    CGFloat = 12
        let total            = iconPt + pad * 2
        let drawRect         = NSRect(x: pad, y: pad, width: iconPt, height: iconPt)

        let cfg = NSImage.SymbolConfiguration(pointSize: iconPt, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        guard let sym = NSImage(systemSymbolName: tool.systemImage,
                                accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else { return .crosshair }

        let img = NSImage(size: NSSize(width: total, height: total), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            if tool == .cutMove { ctx.translateBy(x: total, y: 0); ctx.scaleBy(x: -1, y: 1) }
            glowLayers(ctx: ctx, orange: brandOrange, warm: brandWarm) { sym.draw(in: drawRect) }
            sym.draw(in: drawRect)
            return true
        }
        return NSCursor(image: img, hotSpot: hotSpot(for: tool, pad: pad, icon: iconPt))
    }

    // MARK: - Brush ring cursors (true-to-size stroke footprint)

    private static var brushCache: [String: NSCursor] = [:]

    // White ring at the TRUE stroke diameter + precision crosshair at center.
    // Ring is pure white so it reads on any background; the brand glow provides
    // the color identity — same pattern used by Photoshop / Pixelmator Pro.
    private static func brushCursor(diameter: CGFloat, tool: DrawingTool) -> NSCursor {
        let dia = max(8, min(120, diameter.rounded()))
        let cacheKey = "\(tool.rawValue)-\(Int(dia))"
        if let c = brushCache[cacheKey] { return c }

        let pad: CGFloat = 12
        let total  = dia + pad * 2
        let cx     = total / 2
        let cy     = total / 2
        let ringRect = CGRect(x: pad, y: pad, width: dia, height: dia)
            .insetBy(dx: 0.75, dy: 0.75)

        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        func drawCursor(_ ctx: CGContext) {
            // Ring at true brush footprint
            ctx.addPath(CGPath(ellipseIn: ringRect, transform: nil))
            ctx.setLineWidth(1.5)
            ctx.setStrokeColor(white)
            ctx.strokePath()

            // Small precision crosshair at the exact paint center
            let arm: CGFloat = 4.5
            let gap: CGFloat = 1.5
            ctx.setLineCap(.round)
            ctx.setLineWidth(1.0)
            ctx.setStrokeColor(white)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx - arm, y: cy)); p.addLine(to: CGPoint(x: cx - gap, y: cy))
            p.move(to: CGPoint(x: cx + gap, y: cy)); p.addLine(to: CGPoint(x: cx + arm, y: cy))
            p.move(to: CGPoint(x: cx, y: cy + arm)); p.addLine(to: CGPoint(x: cx, y: cy + gap))
            p.move(to: CGPoint(x: cx, y: cy - arm)); p.addLine(to: CGPoint(x: cx, y: cy - gap))
            ctx.addPath(p); ctx.strokePath()
        }

        let img = NSImage(size: NSSize(width: total, height: total), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            glowLayers(ctx: ctx, orange: brandOrange, warm: brandWarm) { drawCursor(ctx) }
            drawCursor(ctx)
            return true
        }
        let c = NSCursor(image: img, hotSpot: NSPoint(x: total / 2, y: total / 2))
        brushCache[cacheKey] = c
        return c
    }

    // MARK: - Cursor-arrow cursor (shapes + lines)

    private static var _shapeCursor: NSCursor?
    static func shapeCursor() -> NSCursor {
        if let c = _shapeCursor { return c }
        let c = buildCursorArrow()
        _shapeCursor = c
        return c
    }

    static func invalidateShapeCursor() { _shapeCursor = nil }

    private static func buildCursorArrow() -> NSCursor {
        // Match the same canvas size as other tool cursors (iconPt:20 + pad:12 each side)
        let pad:  CGFloat = 12
        let icon: CGFloat = 20
        let total = icon + pad * 2   // 44 pt
        let c     = CGPoint(x: total / 2, y: total / 2)
        let arm:  CGFloat = 9
        let gap:  CGFloat = 2.5
        let lw:   CGFloat = 1.2
        let dotR: CGFloat = 2.0

        func drawCrosshair(_ ctx: CGContext) {
            ctx.setLineCap(.round)
            ctx.setLineWidth(lw)
            ctx.setStrokeColor(CGColor.white)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x - arm, y: c.y)); p.addLine(to: CGPoint(x: c.x - gap, y: c.y))
            p.move(to: CGPoint(x: c.x + gap, y: c.y)); p.addLine(to: CGPoint(x: c.x + arm, y: c.y))
            p.move(to: CGPoint(x: c.x, y: c.y + arm)); p.addLine(to: CGPoint(x: c.x, y: c.y + gap))
            p.move(to: CGPoint(x: c.x, y: c.y - arm)); p.addLine(to: CGPoint(x: c.x, y: c.y - gap))
            ctx.addPath(p)
            ctx.strokePath()
            ctx.setFillColor(CGColor.white)
            ctx.fillEllipse(in: CGRect(x: c.x - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2))
        }

        let img = NSImage(size: NSSize(width: total, height: total), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            glowLayers(ctx: ctx, orange: brandOrange, warm: brandWarm) { drawCrosshair(ctx) }
            drawCrosshair(ctx)
            return true
        }
        // Hot spot at visual center
        return NSCursor(image: img, hotSpot: NSPoint(x: total / 2, y: total / 2))
    }

    // MARK: - Shared glow helper

    private static let brandOrange = CGColor(red: 0.96, green: 0.39, blue: 0.30, alpha: 1)
    private static let brandWarm   = CGColor(red: 1.00, green: 0.55, blue: 0.26, alpha: 1)

    private static func glowLayers(ctx: CGContext,
                                   orange: CGColor, warm: CGColor,
                                   draw: () -> Void) {
        // Wide outer glow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 14, color: orange.copy(alpha: 0.55))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil); draw(); ctx.endTransparencyLayer()
        ctx.restoreGState()
        // Tight inner glow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 6, color: warm.copy(alpha: 0.90))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil); draw(); ctx.endTransparencyLayer()
        ctx.restoreGState()
        // Dark outline for light backgrounds
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 2, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.70))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil); draw(); ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    // MARK: - Hot spots (cursor image coords: top-left = 0,0)

    private static func hotSpot(for tool: DrawingTool, pad: CGFloat, icon: CGFloat) -> NSPoint {
        let mid = pad + icon / 2
        switch tool {
        case .blurBrush:
            return NSPoint(x: mid, y: mid)
        case .marker:
            return NSPoint(x: pad + 2, y: pad + 2)        // brush tip: top-left
        case .pen, .highlighter, .dotPen:
            return NSPoint(x: pad + 2, y: pad + icon - 2) // pencil tip: bottom-left
        case .eraser, .laserPointer, .spotlight:
            return NSPoint(x: mid, y: mid)
        case .cutMove:
            return NSPoint(x: pad + 4, y: pad + 4)
        default:
            return NSPoint(x: mid, y: mid)
        }
    }
}
