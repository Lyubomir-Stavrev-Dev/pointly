import AppKit

enum ToolCursor {
    private static var cache: [DrawingTool: NSCursor] = [:]

    static func cursor(for tool: DrawingTool) -> NSCursor {
        switch tool {
        case .cursor:                                      return .arrow
        case .select:                                      return .arrow
        case .text:                                        return .iBeam
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
        let iconSize: CGFloat = 20
        let pad:      CGFloat = 8
        let total              = iconSize + pad * 2   // 56 pt

        let drawRect = NSRect(x: pad, y: pad, width: iconSize, height: iconSize)

        let cfg = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        guard let sym = NSImage(systemSymbolName: "cursorarrow",
                                accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else { return .arrow }

        // Gradient: orange at tip (top-left) → pink at tail (bottom-right)
        let orange = CGColor(red: 0.96, green: 0.45, blue: 0.08, alpha: 1.0)
        let pink   = CGColor(red: 0.91, green: 0.16, blue: 0.60, alpha: 1.0)
        let cs     = CGColorSpaceCreateDeviceRGB()
        let grad   = CGGradient(colorsSpace: cs,
                                colors: [orange, pink] as CFArray,
                                locations: [0, 1])!

        // NSImage is flipped:false (y-up) — tip sits at high-y/low-x corner
        let gradStart = CGPoint(x: drawRect.minX, y: drawRect.maxY)
        let gradEnd   = CGPoint(x: drawRect.maxX, y: drawRect.minY)

        let img = NSImage(size: NSSize(width: total, height: total), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            func drawSym() { sym.draw(in: drawRect) }

            // Orange glow — tight, near tip
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: -0.5, height: 1.5), blur: 4,
                          color: CGColor(red: 1.0, green: 0.50, blue: 0.08, alpha: 0.9))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil); drawSym(); ctx.endTransparencyLayer()
            ctx.restoreGState()

            // Pink glow — tight, near tail
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 1.5, height: -1.5), blur: 5,
                          color: CGColor(red: 0.85, green: 0.0, blue: 0.65, alpha: 0.9))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil); drawSym(); ctx.endTransparencyLayer()
            ctx.restoreGState()

            // White outline — very tight
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 1.5,
                          color: CGColor.white.copy(alpha: 1.0))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil); drawSym(); ctx.endTransparencyLayer()
            ctx.restoreGState()

            // Gradient-filled arrow (symbol alpha used as clip mask via sourceIn)
            ctx.saveGState()
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            drawSym()                               // lays down the symbol's alpha
            ctx.setBlendMode(.sourceIn)
            ctx.drawLinearGradient(grad, start: gradStart, end: gradEnd,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.endTransparencyLayer()
            ctx.restoreGState()

            return true
        }

        // Hot spot: tip of arrow = top-left in cursor-image coords (0,0 at top-left)
        return NSCursor(image: img, hotSpot: NSPoint(x: pad + 1, y: pad + 1))
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
        case .pen, .highlighter, .marker, .dotPen, .blurBrush:
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
