import SwiftUI

/// Instruments that carry a measured value. The exact figure is always
/// printed beside the instrument, so these show proportion, never text.
extension ActivityInstrumentDrawing {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    // MARK: - Level

    /// Open 270° gauge (Apple Watch style) with a glyph naming the level.
    func drawLevel() {
        let fan = instrument.variant == .fan
        let start: Color = fan ? .teal : .orange
        let end: Color = fan ? .cyan : .yellow
        let center = p(24, 25), radius: CGFloat = 17, width: CGFloat = 5

        pen.arc(center, radius: radius, from: 135, to: 405, start, width: width, opacity: ActivityInstrumentPen.trackOpacity)
        if value > 0 {
            let sweep = 135 + 270 * value
            pen.arc(
                center, radius: radius, from: 135, to: sweep,
                .linearGradient(Gradient(colors: [start, end]), startPoint: p(7, 0), endPoint: p(41, 0)),
                width: width
            )
            pen.knob(ActivityInstrumentPen.polar(center, radius: radius, degrees: sweep), radius: 3.3, outline: end)
        }
        if fan {
            drawFanGlyph(center: center, color: value > 0 ? .teal : .gray)
        } else {
            drawSunGlyph(center: center, color: value > 0 ? .yellow : .gray)
        }
    }

    private func drawSunGlyph(center: CGPoint, color: Color) {
        pen.dot(center, radius: 3.6, color)
        for index in 0..<8 {
            let angle = Double(index) * 45
            pen.line(
                ActivityInstrumentPen.polar(center, radius: 6.2, degrees: angle),
                ActivityInstrumentPen.polar(center, radius: 8.2, degrees: angle),
                color, width: 2
            )
        }
    }

    private func drawFanGlyph(center: CGPoint, color: Color) {
        for index in 0..<3 {
            let blade = Path(ellipseIn: CGRect(x: center.x - 3.2, y: center.y - 10.2, width: 6.4, height: 10.4))
                .applying(rotation(Double(index) * 120, around: center))
            pen.fill(blade, color)
        }
        pen.knockout(center, radius: 2)
    }

    // MARK: - Liquids

    func drawHumidity() {
        var drop = Path()
        drop.move(to: p(24, 5))
        drop.addCurve(to: p(10.5, 29), control1: p(24, 5), control2: p(10.5, 19.5))
        drop.addArc(center: p(24, 29), radius: 13.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        drop.addCurve(to: p(24, 5), control1: p(37.5, 19.5), control2: p(24, 5))
        drop.closeSubpath()
        pen.liquidFill(drop, level: value, bottom: .blue, top: .cyan, span: 5...42.5)

        var highlight = Path()
        highlight.addArc(center: p(24, 30), radius: 7, startAngle: .degrees(180), endAngle: .degrees(125), clockwise: true)
        pen.stroke(highlight, .white.opacity(0.55), width: 2)
    }

    func drawEnergy() {
        let bolt = ActivityInstrumentPen.polygon([
            p(28.5, 4), p(11.5, 27.5), p(22.5, 27.5), p(19, 44), p(36.5, 19.5), p(25.5, 19.5)
        ])
        pen.liquidFill(bolt, level: value, bottom: .orange, top: .yellow, span: 4...44)
    }

    // MARK: - Temperature

    /// One thermometer silhouette; the mercury is coloured by temperature.
    func drawTemperature() {
        let track = ActivityInstrumentPen.trackOpacity
        pen.fill(ActivityInstrumentPen.rounded(18.5, 4, 11, 32, radius: 5.5), tint, opacity: track)
        pen.dot(p(24, 35.5), radius: 8.5, tint, opacity: track)

        let top: CGFloat = 9, bottom: CGFloat = 33
        let surface = bottom - (bottom - top) * value
        pen.fill(ActivityInstrumentPen.rounded(21.5, surface, 5, 36 - surface, radius: 2.5), tint)
        pen.dot(p(24, 35.5), radius: 5.6, tint)

        for index in 0..<3 {
            let y = 11 + CGFloat(index) * 6
            pen.line(p(31.5, y), p(34.5, y), tint, width: 1.8, opacity: 0.45)
        }
    }

    // MARK: - Air quality

    /// Weather-app AQI arc: a fixed green → red scale with a marker.
    func drawAirQuality() {
        let center = p(24, 30), radius: CGFloat = 16
        let gradient = Gradient(stops: [
            .init(color: .green, location: 0),
            .init(color: .yellow, location: 0.4),
            .init(color: .orange, location: 0.7),
            .init(color: .red, location: 1)
        ])
        pen.arc(center, radius: radius, from: 160, to: 380, .linearGradient(gradient, startPoint: p(8, 0), endPoint: p(40, 0)), width: 5.2)

        let marker: Color = value < 0.34 ? .green : value < 0.6 ? .yellow : value < 0.8 ? .orange : .red
        pen.knob(ActivityInstrumentPen.polar(center, radius: radius, degrees: 160 + 220 * value), radius: 4.6)
        pen.ring(ActivityInstrumentPen.polar(center, radius: radius, degrees: 160 + 220 * value), radius: 4.6, marker, width: 2.4)
    }

    // MARK: - Cover

    /// A window with the blind lowered to match the position.
    func drawPosition() {
        let frame = ActivityInstrumentPen.rounded(8, 6, 32, 36, radius: 4)
        pen.fill(frame, .yellow, opacity: 0.16)
        pen.stroke(frame, tint.opacity(0.45), width: 2.4)

        let shade = 30 * (1 - value)
        pen.fill(ActivityInstrumentPen.rounded(10.5, 8.5, 27, max(shade, 1), radius: 1.5), tint)
        let hem = 8.5 + shade + 1.5
        pen.line(p(9, hem), p(39, hem), tint)
        pen.dot(p(24, hem + 4), radius: 1.8, tint)
    }

    // MARK: - Colour

    /// A glossy swatch in the light's actual colour.
    func drawColour() {
        let disc = Path(ellipseIn: ActivityInstrumentPen.circle(p(24, 24), 16))
        if let swatch = instrument.swatch {
            pen.fill(disc, swatch)
        } else {
            let hues: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
            pen.fill(disc, .conicGradient(Gradient(colors: hues), center: p(24, 24)))
        }
        pen.fill(disc, .radialGradient(
            Gradient(stops: [.init(color: .white.opacity(0.5), location: 0), .init(color: .white.opacity(0), location: 0.55)]),
            center: p(19.2, 17.6), startRadius: 0, endRadius: 24
        ))
        pen.ring(p(24, 24), radius: 16, .primary, width: 0.8, opacity: 0.12)
    }

    // MARK: - Trend

    /// Stocks-style sparkline with an area gradient and a haloed endpoint.
    func drawTrend() {
        let points = trendPoints
        var area = Path()
        area.addLines(points)
        area.addLine(to: p(42.24, 42.24))
        area.addLine(to: p(5.76, 42.24))
        area.closeSubpath()
        pen.fill(area, .linearGradient(
            Gradient(colors: [tint.opacity(0.32), tint.opacity(0)]),
            startPoint: p(0, 5.76), endPoint: p(0, 42.24)
        ))
        pen.polyline(points, tint)
        if let last = points.last {
            pen.dot(last, radius: 6.2, tint, opacity: 0.22)
            pen.dot(last, radius: 3.4, tint)
        }
    }

    private var trendPoints: [CGPoint] {
        let shape: [(CGFloat, CGFloat)]
        switch instrument.trend {
        case .rising: shape = [(0, 0.78), (0.24, 0.68), (0.46, 0.7), (0.7, 0.38), (1, 0.2)]
        case .falling: shape = [(0, 0.2), (0.24, 0.32), (0.46, 0.28), (0.7, 0.62), (1, 0.78)]
        case .steady, .none: shape = [(0, 0.5), (0.24, 0.46), (0.48, 0.54), (0.72, 0.48), (1, 0.5)]
        }
        return shape.map { p(5.76 + 36.48 * $0.0, 5.76 + 36.48 * $0.1) }
    }

    // MARK: - Signal and battery

    /// Solid rounded bars on a common baseline, like SF `cellularbars`.
    func drawSignal() {
        for index in 0..<4 {
            let height = 8 + CGFloat(index) * 7
            let active = Double(index + 1) / 4 <= value + 0.12
            pen.fill(
                ActivityInstrumentPen.rounded(7 + CGFloat(index) * 9.2, 40 - height, 6.4, height, radius: 2.2),
                tint, opacity: active ? 1 : ActivityInstrumentPen.trackOpacity
            )
        }
    }

    /// The iOS status-bar battery: neutral shell, solid nub, even gap.
    func drawBattery() {
        pen.stroke(ActivityInstrumentPen.rounded(4, 14.5, 36, 19, radius: 6), Color.primary.opacity(0.35), width: 2.2)
        var nub = Path()
        nub.addArc(center: p(42, 24), radius: 3.5, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        nub.closeSubpath()
        pen.fill(nub, .primary, opacity: 0.4)

        let fill: Color = value <= 0.2 ? .red : .green
        pen.fill(ActivityInstrumentPen.rounded(7.4, 17.9, max(29.2 * value, 3), 12.2, radius: 3.6), fill)
    }

    func rotation(_ degrees: Double, around center: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -center.x, y: -center.y)
    }
}
