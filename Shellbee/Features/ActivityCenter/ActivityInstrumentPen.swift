import SwiftUI

/// Drawing primitives for Activity instruments. Every instrument is authored
/// on a square grid of `DesignTokens.ActivityInstrument.grid` units; the view
/// scales the context, so coordinates here never depend on the rendered size.
struct ActivityInstrumentPen {
    let context: GraphicsContext

    static let markWidth = DesignTokens.ActivityInstrument.markWidth
    static let trackOpacity = DesignTokens.ActivityInstrument.trackOpacity

    // MARK: - Strokes

    func line(_ from: CGPoint, _ to: CGPoint, _ color: Color, width: CGFloat = markWidth, opacity: Double = 1) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        stroke(path, color.opacity(opacity), width: width)
    }

    func polyline(_ points: [CGPoint], _ color: Color, width: CGFloat = markWidth, opacity: Double = 1) {
        var path = Path()
        path.addLines(points)
        stroke(path, color.opacity(opacity), width: width)
    }

    func ring(_ center: CGPoint, radius: CGFloat, _ color: Color, width: CGFloat = markWidth, opacity: Double = 1) {
        stroke(Path(ellipseIn: Self.circle(center, radius)), color.opacity(opacity), width: width)
    }

    /// Angles in degrees, 0 pointing right, increasing clockwise on screen.
    func arc(
        _ center: CGPoint, radius: CGFloat, from start: Double, to end: Double,
        _ shading: GraphicsContext.Shading, width: CGFloat = markWidth
    ) {
        guard end > start else { return }
        stroke(Self.arcPath(center, radius: radius, from: start, to: end), shading, width: width)
    }

    func arc(
        _ center: CGPoint, radius: CGFloat, from start: Double, to end: Double,
        _ color: Color, width: CGFloat = markWidth, opacity: Double = 1
    ) {
        arc(center, radius: radius, from: start, to: end, .color(color.opacity(opacity)), width: width)
    }

    func stroke(_ path: Path, _ color: Color, width: CGFloat = markWidth) {
        stroke(path, .color(color), width: width)
    }

    func stroke(_ path: Path, _ shading: GraphicsContext.Shading, width: CGFloat = markWidth) {
        context.stroke(path, with: shading, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Fills

    func dot(_ center: CGPoint, radius: CGFloat, _ color: Color, opacity: Double = 1) {
        context.fill(Path(ellipseIn: Self.circle(center, radius)), with: .color(color.opacity(opacity)))
    }

    func fill(_ path: Path, _ color: Color, opacity: Double = 1) {
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    func fill(_ path: Path, _ shading: GraphicsContext.Shading) {
        context.fill(path, with: shading)
    }

    /// Fills a shape with a faint track, then fills it from the bottom up to
    /// `level` with a gradient running `bottom` → `top`.
    func liquidFill(_ shape: Path, level: Double, bottom: Color, top: Color, span: ClosedRange<CGFloat>) {
        fill(shape, bottom, opacity: Self.trackOpacity)
        guard level > 0 else { return }
        let surface = span.upperBound - (span.upperBound - span.lowerBound) * level
        context.drawLayer { layer in
            layer.clip(to: shape)
            layer.fill(
                Path(CGRect(x: 0, y: surface, width: DesignTokens.ActivityInstrument.grid, height: span.upperBound - surface + 4)),
                with: .linearGradient(
                    Gradient(colors: [top, bottom]),
                    startPoint: CGPoint(x: 0, y: span.lowerBound),
                    endPoint: CGPoint(x: 0, y: span.upperBound)
                )
            )
        }
    }

    /// Punches a transparent hole, so cut-outs (a keyhole, a gear's hub)
    /// show whatever surface the instrument sits on.
    func knockout(_ path: Path) {
        var eraser = context
        eraser.blendMode = .destinationOut
        eraser.fill(path, with: .color(.black))
    }

    func knockout(_ center: CGPoint, radius: CGFloat) {
        knockout(Path(ellipseIn: Self.circle(center, radius)))
    }

    func knockoutLine(_ from: CGPoint, _ to: CGPoint, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        knockout(path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round)))
    }

    /// A white knob with the soft drop shadow of an iOS control.
    func knob(_ center: CGPoint, radius: CGFloat, outline: Color? = nil) {
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.28), radius: 1.2, x: 0, y: 0.8))
            layer.fill(Path(ellipseIn: Self.circle(center, radius)), with: .color(.white))
        }
        if let outline {
            ring(center, radius: radius, outline, width: 1.2)
        }
    }

    // MARK: - Geometry

    static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static func polar(_ center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    static func arcPath(_ center: CGPoint, radius: CGFloat, from start: Double, to end: Double) -> Path {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        return path
    }

    static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    static func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius, style: .continuous)
    }
}
