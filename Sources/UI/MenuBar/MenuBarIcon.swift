import Cocoa

/// Custom vector Menu Bar icon renderer for MacDots
public enum MenuBarIcon {
    /// Generates a sleek, high-DPI vector menu bar template icon
    public static func create(isActive: Bool = true) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // 1. Sleek minimal screen display border
            let displayRect = CGRect(x: 1.5, y: 3.5, width: 15.0, height: 11.0)
            let displayPath = CGPath(roundedRect: displayRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.25)
            ctx.addPath(displayPath)
            ctx.strokePath()

            // 2. Left motion dots (2 delicate dots inside left edge)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(x: 3.6, y: 5.4, width: 2.0, height: 2.0))
            ctx.fillEllipse(in: CGRect(x: 3.6, y: 10.4, width: 2.0, height: 2.0))

            // 3. Right motion dots (2 delicate dots inside right edge)
            ctx.fillEllipse(in: CGRect(x: 12.4, y: 5.4, width: 2.0, height: 2.0))
            ctx.fillEllipse(in: CGRect(x: 12.4, y: 10.4, width: 2.0, height: 2.0))

            // 4. Center horizon stabilization indicator
            ctx.setLineWidth(1.0)
            ctx.move(to: CGPoint(x: 7.2, y: 9.0))
            ctx.addLine(to: CGPoint(x: 10.8, y: 9.0))
            ctx.strokePath()

            return true
        }

        image.isTemplate = true
        return image
    }
}
