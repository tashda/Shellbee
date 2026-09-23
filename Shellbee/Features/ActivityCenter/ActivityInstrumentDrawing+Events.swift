import SwiftUI

/// Bridge, network and event instruments. They carry no value, so each is a
/// shape people already know rather than a diagram that needs a legend.
extension ActivityInstrumentDrawing {
    // MARK: - Firmware

    /// App Store download ring; a green check when done, a red "!" on failure.
    func drawUpdate() {
        if instrument.severity == .failure {
            pen.dot(p(24, 24), radius: 17, tint)
            pen.line(p(24, 14.5), p(24, 26), .white, width: 3.8)
            pen.dot(p(24, 32), radius: 2.3, .white)
        } else if value >= 1 {
            pen.dot(p(24, 24), radius: 17, .green)
            pen.polyline([p(16, 24.5), p(21.5, 30), p(32, 18.5)], .white, width: 3.8)
        } else {
            pen.ring(p(24, 24), radius: 16, tint, opacity: ActivityInstrumentPen.trackOpacity)
            pen.arc(p(24, 24), radius: 16, from: -90, to: -90 + 360 * value, tint)
            pen.fill(ActivityInstrumentPen.rounded(19.5, 19.5, 9, 9, radius: 2), tint)
        }
    }

    // MARK: - Pairing

    func drawPairing() {
        if instrument.variant == .permitJoin {
            drawRadioWaves()
        } else {
            drawChainLink()
        }
    }

    private func drawChainLink() {
        let first = ActivityInstrumentPen.rounded(4, 19, 23, 11, radius: 5.5)
            .applying(rotation(-45, around: p(15.5, 24.5)))
        let second = ActivityInstrumentPen.rounded(21, 18, 23, 11, radius: 5.5)
            .applying(rotation(-45, around: p(32.5, 23.5)))
        pen.stroke(first, tint)
        pen.stroke(second, tint)
    }

    /// Permit join: waves when open, gray with a slash when closed.
    private func drawRadioWaves() {
        pen.dot(p(24, 24), radius: 4.5, tint)
        for (index, radius) in [10, 17].enumerated() {
            let opacity = 1 - Double(index) * 0.35
            pen.arc(p(24, 24), radius: CGFloat(radius), from: -40, to: 40, tint, width: 3, opacity: opacity)
            pen.arc(p(24, 24), radius: CGFloat(radius), from: 140, to: 220, tint, width: 3, opacity: opacity)
        }
        if !instrument.isOn {
            pen.knockoutLine(p(9, 39), p(39, 9), width: 6.5)
            pen.line(p(9, 39), p(39, 9), tint, width: 3)
        }
    }

    // MARK: - Group and network

    /// Three overlapping members, like the Groups avatar stacks.
    func drawGroup() {
        let members: [(CGPoint, Double)] = [(p(24, 16), 0.55), (p(16, 30), 0.8), (p(32, 30), 1)]
        for (center, opacity) in members {
            pen.knockout(center, radius: 10)
            pen.dot(center, radius: 9, tint, opacity: opacity)
        }
    }

    /// A coordinator with a halo and four routers around it.
    func drawNetwork() {
        let center = p(24, 24)
        let routers = [p(9, 14), p(39, 12), p(37, 37), p(11, 36)]
        for router in routers {
            pen.line(center, router, tint, width: 2.4, opacity: 0.45)
        }
        pen.line(routers[0], routers[3], tint, width: 2, opacity: 0.3)
        pen.line(routers[1], routers[2], tint, width: 2, opacity: 0.3)
        for router in routers {
            pen.dot(router, radius: 4, tint)
        }
        pen.dot(center, radius: 9, tint, opacity: 0.22)
        pen.dot(center, radius: 6, tint)
    }

    /// Three makers, each a distinct mark on the same baseline.
    func drawVendors() {
        for (x, top, opacity) in [(10.0, 17.0, 0.65), (24.0, 12.0, 1.0), (38.0, 19.0, 0.8)] {
            pen.dot(p(x, top), radius: 4.2, tint, opacity: opacity)
            pen.line(p(x, top + 7), p(x, 38), tint, width: 4, opacity: opacity)
        }
    }

    /// Three device forms, drawn like the other tiny Activity marks.
    func drawModels() {
        pen.stroke(ActivityInstrumentPen.rounded(5, 18, 11, 21, radius: 3), tint, width: 3)
        pen.stroke(ActivityInstrumentPen.rounded(20, 8, 12, 31, radius: 3), tint, width: 3)
        pen.stroke(ActivityInstrumentPen.rounded(36, 22, 8, 17, radius: 2.5), tint, width: 3)
    }

    func drawTouchlink() {
        pen.dot(p(12, 24), radius: 4.2, tint)
        for (index, radius) in [9, 16, 23].enumerated() {
            pen.arc(p(12, 24), radius: CGFloat(radius), from: -42, to: 42, tint, width: 3, opacity: 1 - Double(index) * 0.28)
        }
    }

    // MARK: - Actions and bridge operations

    /// A tap ripple: solid centre with two fading rings.
    func drawAction() {
        pen.ring(p(24, 24), radius: 19, tint, width: 2.2, opacity: 0.25)
        pen.ring(p(24, 24), radius: 12.5, tint, width: 2.8, opacity: 0.55)
        pen.dot(p(24, 24), radius: 6.5, tint)
    }

    func drawHealth() {
        let shape: [(CGFloat, CGFloat)] = [(0, 0.55), (0.24, 0.55), (0.36, 0.24), (0.48, 0.8), (0.59, 0.42), (0.72, 0.55), (1, 0.55)]
        pen.polyline(shape.map { p(5.76 + 36.48 * $0.0, 5.76 + 36.48 * $0.1) }, tint)
    }

    /// An arrow going down into a tray.
    func drawBackup() {
        var tray = Path()
        tray.move(to: p(7, 26))
        tray.addArc(tangent1End: p(7, 40), tangent2End: p(41, 40), radius: 5)
        tray.addArc(tangent1End: p(41, 40), tangent2End: p(41, 26), radius: 5)
        tray.addLine(to: p(41, 26))
        pen.stroke(tray, tint)
        pen.line(p(24, 6), p(24, 29), tint)
        pen.polyline([p(16.5, 21.5), p(24, 29), p(31.5, 21.5)], tint)
    }

    /// A clockwise arrow with a real arrowhead.
    func drawRestart() {
        let center = p(24, 25), radius: CGFloat = 14, end = 285.0
        pen.arc(center, radius: radius, from: 10, to: end, tint)

        let tip = ActivityInstrumentPen.polar(center, radius: radius, degrees: end)
        let radians = end * .pi / 180
        let tangent = CGPoint(x: -sin(radians), y: cos(radians))
        let normal = CGPoint(x: cos(radians), y: sin(radians))
        let head = ActivityInstrumentPen.polygon([
            p(tip.x + tangent.x * 5.5, tip.y + tangent.y * 5.5),
            p(tip.x + normal.x * 5 - tangent.x * 1.2, tip.y + normal.y * 5 - tangent.y * 1.2),
            p(tip.x - normal.x * 5 - tangent.x * 1.2, tip.y - normal.y * 5 - tangent.y * 1.2)
        ])
        pen.fill(head, tint)
        pen.stroke(head, tint, width: 1.5)
    }

    func drawOptions() {
        var gear = Path(ellipseIn: ActivityInstrumentPen.circle(p(24, 24), 14.5))
        for index in 0..<8 {
            gear.addPath(
                ActivityInstrumentPen.rounded(20.5, 4.5, 7, 9, radius: 2),
                transform: rotation(Double(index) * 45, around: p(24, 24))
            )
        }
        pen.fill(gear, tint)
        pen.knockout(p(24, 24), radius: 5.5)
    }

    // MARK: - Messages

    /// Info: a speech bubble. Warnings and errors share the alarm triangle.
    func drawMessage() {
        if instrument.severity == .warning || instrument.severity == .failure {
            drawAlert(tint)
            return
        }
        var bubble = ActivityInstrumentPen.rounded(5, 8, 38, 26, radius: 8)
        bubble.addPath(ActivityInstrumentPen.polygon([p(13, 32), p(11, 41), p(21, 33)]))
        pen.fill(bubble, tint)
        for x in [16.0, 24.0, 32.0] as [CGFloat] {
            pen.knockout(p(x, 21), radius: 2.3)
        }
    }

    /// Kept deliberately generic: Shellbee doesn't know this one yet.
    func drawUnknown() {
        let circle = Path(ellipseIn: ActivityInstrumentPen.circle(p(24, 24), 12.4))
        pen.context.stroke(circle, with: .color(tint), style: StrokeStyle(lineWidth: 1.7, dash: [2.6, 4.8]))
        pen.dot(p(24, 24), radius: 2.6, tint)
    }
}
