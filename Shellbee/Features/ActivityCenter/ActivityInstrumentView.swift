import SwiftUI

/// A compact, bespoke micro-visual for an Activity event. It deliberately
/// avoids icon wells: the mark itself carries the value, trend, or topology.
struct ActivityInstrumentView: View {
    let instrument: ActivityInstrument
    var size: CGFloat = DesignTokens.ActivityInstrument.size

    var body: some View {
        Canvas { context, canvasSize in
            var drawing = ActivityInstrumentDrawing(
                instrument: instrument,
                context: context,
                size: canvasSize
            )
            drawing.draw()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(instrument.accessibilityDescription)
    }
}

private struct ActivityInstrumentDrawing {
    let instrument: ActivityInstrument
    var context: GraphicsContext
    let size: CGSize

    private var edge: CGFloat { min(size.width, size.height) }
    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
    private var inset: CGFloat { edge * DesignTokens.ActivityInstrument.chartInsetRatio }
    private var primaryWidth: CGFloat { edge * DesignTokens.ActivityInstrument.primaryStrokeRatio }
    private var secondaryWidth: CGFloat { edge * DesignTokens.ActivityInstrument.secondaryStrokeRatio }
    private var tint: Color { instrument.tint }
    private var muted: Color { tint.opacity(DesignTokens.ActivityInstrument.inactiveOpacity) }
    private var plot: CGRect { CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset) }

    mutating func draw() {
        switch instrument.kind {
        case .level: drawGauge()
        case .binary: drawBinary()
        case .trend: drawTrend()
        case .temperature: drawThermometer()
        case .humidity: drawDroplet()
        case .airQuality: drawAirQuality()
        case .energy: drawEnergy()
        case .position: drawPosition()
        case .colour: drawColour()
        case .signal: drawSignal()
        case .battery: drawBattery()
        case .presence: drawPresence()
        case .safety: drawSafety()
        case .action: drawAction()
        case .network: drawNetwork()
        case .health: drawHealth()
        case .backup: drawBackup()
        case .restart: drawRestart()
        case .options: drawOptions()
        case .update: drawUpdate()
        case .pairing: drawPairing()
        case .group: drawGroup()
        case .touchlink: drawTouchlink()
        case .lifecycle: drawLifecycle()
        case .message: drawMessage()
        case .unknown: drawUnknown()
        }
    }

    private mutating func drawGauge() {
        let radius = plot.width * 0.42
        circle(center: center, radius: radius, color: muted, width: primaryWidth)
        arc(center: center, radius: radius, from: -90, to: -90 + 360 * instrument.normalizedValue, color: tint, width: primaryWidth)
        drawPrimaryText()
    }

    private mutating func drawBinary() {
        let radius = plot.width * 0.14
        let left = CGPoint(x: plot.minX + plot.width * 0.27, y: center.y)
        let right = CGPoint(x: plot.maxX - plot.width * 0.27, y: center.y)
        line(from: left, to: right, color: muted, width: secondaryWidth)
        filledCircle(center: left, radius: radius, color: instrument.normalizedValue < 0.5 ? tint : muted)
        filledCircle(center: right, radius: radius, color: instrument.normalizedValue >= 0.5 ? tint : muted)
    }

    private mutating func drawTrend() {
        let points = trendPoints()
        polyline(points, color: tint, width: primaryWidth)
        if let last = points.last { filledCircle(center: last, radius: primaryWidth, color: tint) }
    }

    private mutating func drawThermometer() {
        let x = center.x
        let top = plot.minY + plot.height * 0.12
        let bottom = plot.maxY - plot.height * 0.2
        let bulbRadius = plot.width * 0.13
        line(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: bottom), color: muted, width: primaryWidth * 2)
        let fillTop = bottom - (bottom - top) * instrument.normalizedValue
        line(from: CGPoint(x: x, y: fillTop), to: CGPoint(x: x, y: bottom), color: tint, width: primaryWidth * 2)
        filledCircle(center: CGPoint(x: x, y: plot.maxY - bulbRadius), radius: bulbRadius, color: tint)
    }

    private mutating func drawDroplet() {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: plot.minY))
        path.addCurve(
            to: CGPoint(x: center.x, y: plot.maxY),
            control1: CGPoint(x: plot.minX, y: center.y),
            control2: CGPoint(x: plot.minX, y: plot.maxY)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: plot.minY),
            control1: CGPoint(x: plot.maxX, y: plot.maxY),
            control2: CGPoint(x: plot.maxX, y: center.y)
        )
        context.stroke(path, with: .color(muted), lineWidth: secondaryWidth)
        let level = plot.maxY - plot.height * instrument.normalizedValue
        line(from: CGPoint(x: plot.minX + plot.width * 0.28, y: level), to: CGPoint(x: plot.maxX - plot.width * 0.28, y: level), color: tint, width: primaryWidth)
    }

    private mutating func drawAirQuality() {
        let rows = 3
        for index in 0..<rows {
            let y = plot.minY + plot.height * CGFloat(index + 1) / CGFloat(rows + 1)
            let progress = min(max(instrument.normalizedValue * CGFloat(rows) - CGFloat(index), 0), 1)
            line(from: CGPoint(x: plot.minX, y: y), to: CGPoint(x: plot.maxX, y: y), color: muted, width: secondaryWidth)
            line(from: CGPoint(x: plot.minX, y: y), to: CGPoint(x: plot.minX + plot.width * progress, y: y), color: tint, width: primaryWidth)
        }
    }

    private mutating func drawEnergy() {
        let bars = 4
        for index in 0..<bars {
            let x = plot.minX + plot.width * CGFloat(index) / CGFloat(bars - 1)
            let height = plot.height * (0.25 + 0.75 * min(max(instrument.normalizedValue + CGFloat(index - 2) * 0.08, 0), 1))
            line(from: CGPoint(x: x, y: plot.maxY), to: CGPoint(x: x, y: plot.maxY - height), color: index == bars - 1 ? tint : muted, width: primaryWidth)
        }
    }

    private mutating func drawPosition() {
        let left = CGPoint(x: plot.minX, y: center.y)
        let right = CGPoint(x: plot.maxX, y: center.y)
        line(from: left, to: right, color: muted, width: primaryWidth)
        let x = plot.minX + plot.width * instrument.normalizedValue
        line(from: CGPoint(x: x, y: plot.minY), to: CGPoint(x: x, y: plot.maxY), color: tint, width: primaryWidth)
    }

    private mutating func drawColour() {
        let radius = plot.width * 0.36
        circle(center: center, radius: radius, color: muted, width: secondaryWidth)
        for index in 0..<3 {
            let angle = Double(index) * 120 - 90
            let point = polar(center: center, radius: radius, degrees: angle)
            filledCircle(center: point, radius: primaryWidth, color: tint.opacity(1 - Double(index) * 0.24))
        }
    }

    private mutating func drawSignal() {
        let bars = 4
        for index in 0..<bars {
            let x = plot.minX + plot.width * CGFloat(index) / CGFloat(bars - 1)
            let height = plot.height * CGFloat(index + 1) / CGFloat(bars + 1)
            let active = CGFloat(index + 1) / CGFloat(bars) <= instrument.normalizedValue + 0.12
            line(from: CGPoint(x: x, y: plot.maxY), to: CGPoint(x: x, y: plot.maxY - height), color: active ? tint : muted, width: primaryWidth)
        }
    }

    private mutating func drawBattery() {
        let body = CGRect(x: plot.minX, y: center.y - plot.height * 0.22, width: plot.width * 0.82, height: plot.height * 0.44)
        roundedRect(body, radius: body.height * 0.24, color: muted, width: secondaryWidth)
        let capX = body.maxX + plot.width * 0.06
        line(from: CGPoint(x: capX, y: center.y - body.height * 0.13), to: CGPoint(x: capX, y: center.y + body.height * 0.13), color: muted, width: primaryWidth)
        let fillWidth = max(body.width * instrument.normalizedValue - primaryWidth, 0)
        if fillWidth > 0 {
            let fill = CGRect(x: body.minX + primaryWidth, y: body.minY + primaryWidth, width: fillWidth, height: body.height - primaryWidth * 2)
            context.fill(Path(roundedRect: fill, cornerRadius: fill.height * 0.2), with: .color(tint))
        }
    }

    private mutating func drawPresence() {
        circle(center: center, radius: plot.width * 0.34, color: muted, width: secondaryWidth)
        filledCircle(center: center, radius: plot.width * 0.1, color: tint)
        arc(center: center, radius: plot.width * 0.23, from: -55, to: 55, color: tint, width: primaryWidth)
    }

    private mutating func drawSafety() {
        let top = CGPoint(x: center.x, y: plot.minY)
        var path = Path()
        path.move(to: top)
        path.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        path.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        path.closeSubpath()
        context.stroke(path, with: .color(muted), lineWidth: secondaryWidth)
        line(from: CGPoint(x: center.x, y: center.y - plot.height * 0.16), to: CGPoint(x: center.x, y: center.y + plot.height * 0.12), color: tint, width: primaryWidth)
        filledCircle(center: CGPoint(x: center.x, y: plot.maxY - plot.height * 0.16), radius: primaryWidth * 0.75, color: tint)
    }

    private mutating func drawAction() {
        circle(center: center, radius: plot.width * 0.28, color: muted, width: secondaryWidth)
        filledCircle(center: center, radius: plot.width * 0.11, color: tint)
        let endpoint = polar(center: center, radius: plot.width * 0.43, degrees: trendAngle)
        line(from: center, to: endpoint, color: tint, width: primaryWidth)
    }

    private mutating func drawNetwork() {
        nodes([(0.14, 0.64), (0.42, 0.18), (0.82, 0.38), (0.7, 0.82)], links: [(0, 1), (1, 2), (1, 3), (2, 3)])
    }

    private mutating func drawHealth() {
        let points: [CGPoint] = [
            point(0, 0.55), point(0.24, 0.55), point(0.36, 0.28), point(0.48, 0.78),
            point(0.59, 0.45), point(0.72, 0.55), point(1, 0.55)
        ]
        polyline(points, color: tint, width: primaryWidth)
    }

    private mutating func drawBackup() {
        for index in 0..<3 {
            let offset = CGFloat(index) * plot.height * 0.2
            let rect = CGRect(x: plot.minX + offset * 0.18, y: plot.minY + offset, width: plot.width - offset * 0.36, height: plot.height * 0.24)
            roundedRect(rect, radius: rect.height * 0.35, color: index == 2 ? tint : muted, width: primaryWidth)
        }
    }

    private mutating func drawRestart() {
        arc(center: center, radius: plot.width * 0.36, from: -60, to: 250, color: tint, width: primaryWidth)
        let tip = polar(center: center, radius: plot.width * 0.36, degrees: -60)
        filledCircle(center: tip, radius: primaryWidth * 1.3, color: tint)
    }

    private mutating func drawOptions() {
        for index in 0..<3 {
            let y = plot.minY + plot.height * CGFloat(index + 1) / 4
            line(from: CGPoint(x: plot.minX, y: y), to: CGPoint(x: plot.maxX, y: y), color: muted, width: secondaryWidth)
            let x = plot.minX + plot.width * [0.28, 0.68, 0.44][index]
            filledCircle(center: CGPoint(x: x, y: y), radius: primaryWidth * 1.4, color: tint)
        }
    }

    private mutating func drawUpdate() {
        let radius = plot.width * 0.36
        circle(center: center, radius: radius, color: muted, width: primaryWidth)
        arc(center: center, radius: radius, from: -90, to: -90 + 360 * instrument.normalizedValue, color: tint, width: primaryWidth)
        line(from: CGPoint(x: center.x, y: plot.minY + plot.height * 0.25), to: CGPoint(x: center.x, y: plot.maxY - plot.height * 0.25), color: tint, width: primaryWidth)
    }

    private mutating func drawPairing() {
        let left = point(0.3, 0.52)
        let right = point(0.7, 0.52)
        circle(center: left, radius: plot.width * 0.19, color: tint, width: primaryWidth)
        circle(center: right, radius: plot.width * 0.19, color: tint, width: primaryWidth)
        line(from: left, to: right, color: muted, width: secondaryWidth)
    }

    private mutating func drawGroup() {
        nodes([(0.16, 0.5), (0.5, 0.18), (0.84, 0.5), (0.5, 0.82)], links: [(0, 1), (1, 2), (2, 3), (3, 0)])
    }

    private mutating func drawTouchlink() {
        let origin = CGPoint(x: plot.minX, y: plot.maxY)
        for fraction in [0.36, 0.62, 0.88] {
            arc(center: origin, radius: plot.width * fraction, from: -90, to: 0, color: fraction == 0.88 ? tint : muted, width: primaryWidth)
        }
        filledCircle(center: origin, radius: primaryWidth, color: tint)
    }

    private mutating func drawLifecycle() {
        let left = CGPoint(x: plot.minX, y: center.y)
        let right = CGPoint(x: plot.maxX, y: center.y)
        line(from: left, to: right, color: muted, width: secondaryWidth)
        filledCircle(center: instrument.trend == .falling ? left : right, radius: plot.width * 0.11, color: tint)
        filledCircle(center: instrument.trend == .falling ? right : left, radius: plot.width * 0.05, color: muted)
    }

    private mutating func drawMessage() {
        for index in 0..<3 {
            let y = plot.minY + plot.height * CGFloat(index + 1) / 4
            let end = index == 2 ? plot.minX + plot.width * 0.66 : plot.maxX
            line(from: CGPoint(x: plot.minX, y: y), to: CGPoint(x: end, y: y), color: index == 0 ? tint : muted, width: primaryWidth)
        }
    }

    private mutating func drawUnknown() {
        let radius = plot.width * 0.34
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: secondaryWidth, dash: [primaryWidth, primaryWidth * 1.8]))
        filledCircle(center: center, radius: primaryWidth, color: tint)
    }

    private var trendAngle: Double {
        switch instrument.trend {
        case .rising: return -40
        case .falling: return 40
        case .steady, .none: return 0
        }
    }

    private func trendPoints() -> [CGPoint] {
        switch instrument.trend {
        case .rising: return [point(0, 0.78), point(0.24, 0.68), point(0.46, 0.7), point(0.7, 0.38), point(1, 0.2)]
        case .falling: return [point(0, 0.2), point(0.24, 0.32), point(0.46, 0.28), point(0.7, 0.62), point(1, 0.78)]
        case .steady, .none: return [point(0, 0.5), point(0.24, 0.46), point(0.48, 0.54), point(0.72, 0.48), point(1, 0.5)]
        }
    }

    private mutating func drawPrimaryText() {
        guard let primaryText = instrument.primaryText else { return }
        context.draw(
            Text(primaryText)
                .font(.system(size: edge * DesignTokens.ActivityInstrument.valueFontRatio, weight: .semibold))
                .foregroundStyle(tint),
            at: center
        )
    }

    private mutating func nodes(_ positions: [(CGFloat, CGFloat)], links: [(Int, Int)]) {
        let points = positions.map { point($0.0, $0.1) }
        for link in links {
            line(from: points[link.0], to: points[link.1], color: muted, width: secondaryWidth)
        }
        for (index, node) in points.enumerated() {
            filledCircle(center: node, radius: primaryWidth * (index == 1 ? 1.55 : 1.2), color: index == 1 ? tint : tint.opacity(0.72))
        }
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: plot.minX + plot.width * x, y: plot.minY + plot.height * y)
    }

    private func polar(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
    }

    private mutating func line(from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private mutating func polyline(_ points: [CGPoint], color: Color, width: CGFloat) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private mutating func circle(center: CGPoint, radius: CGFloat, color: Color, width: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: width)
    }

    private mutating func filledCircle(center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private mutating func roundedRect(_ rect: CGRect, radius: CGFloat, color: Color, width: CGFloat) {
        context.stroke(Path(roundedRect: rect, cornerRadius: radius), with: .color(color), lineWidth: width)
    }

    private mutating func arc(center: CGPoint, radius: CGFloat, from: Double, to: Double, color: Color, width: CGFloat) {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.lg) {
        ActivityInstrumentView(instrument: .init(kind: .level, normalizedValue: 0.8, primaryText: "80"))
        ActivityInstrumentView(instrument: .init(kind: .network))
        ActivityInstrumentView(instrument: .init(kind: .battery, normalizedValue: 0.18, severity: .warning))
        ActivityInstrumentView(instrument: .init(kind: .safety, severity: .failure))
    }
    .padding()
}
