import SwiftUI

/// Two-state instruments. Each has a lit form (on, open, detected, alarm)
/// and an unlit form, so what happened reads before the text does.
extension ActivityInstrumentDrawing {
    // MARK: - Binary

    func drawBinary() {
        switch instrument.variant {
        case .contact: drawDoor()
        case .lock: drawPadlock()
        default: drawToggle()
        }
    }

    /// An iOS switch: green with the knob right when on, gray and left when off.
    private func drawToggle() {
        let track = ActivityInstrumentPen.rounded(5, 14, 38, 20, radius: 10)
        if instrument.isOn {
            pen.fill(track, tint)
        } else {
            pen.fill(track, Color(uiColor: .systemFill))
        }
        pen.knob(p(instrument.isOn ? 33 : 15, 24), radius: 8)
    }

    /// Z2M reports contact as "closed"; the resolver inverts it, so lit = open.
    private func drawDoor() {
        let open = instrument.isOn
        pen.stroke(ActivityInstrumentPen.rounded(10, 5, 28, 38, radius: 3), tint.opacity(open ? 0.45 : 0.6), width: 2.6)
        if open {
            let leaf = ActivityInstrumentPen.polygon([p(12.5, 7.5), p(24, 11), p(24, 44), p(12.5, 40.5)])
            pen.fill(leaf, tint)
            pen.stroke(leaf, tint, width: 1.4)
            pen.knockout(p(21, 27), radius: 1.6)
        } else {
            pen.fill(ActivityInstrumentPen.rounded(12.5, 7.5, 23, 33, radius: 1.5), tint, opacity: 0.9)
            pen.knockout(p(31, 24.5), radius: 1.8)
        }
    }

    private func drawPadlock() {
        let locked = instrument.isOn
        let top: CGFloat = locked ? 15.5 : 13.5
        var shackle = Path()
        shackle.move(to: p(16, 22))
        shackle.addLine(to: p(16, top))
        shackle.addArc(center: p(24, top), radius: 8, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        shackle.addLine(to: p(32, locked ? 22 : 15))
        pen.stroke(shackle, tint, width: 4)

        pen.fill(ActivityInstrumentPen.rounded(11, 21, 26, 21, radius: 5), tint)
        pen.knockout(p(24, 30), radius: 2.4)
        pen.knockoutLine(p(24, 30), p(24, 35), width: 2.4)
    }

    // MARK: - Presence

    /// Solid person when someone is there, a gray outline when clear.
    func drawPresence() {
        if instrument.isOn {
            pen.dot(p(24, 16), radius: 7.5, tint)
            pen.fill(shoulders(bottom: 42, top: 26.5, halfWidth: 16), tint)
        } else {
            pen.ring(p(24, 16), radius: 6.5, tint, width: 3)
            pen.stroke(shoulders(bottom: 41, top: 28, halfWidth: 14.5), tint, width: 3)
        }
    }

    private func shoulders(bottom: CGFloat, top: CGFloat, halfWidth: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(24 - halfWidth, bottom))
        path.addCurve(to: p(24, top), control1: p(24 - halfWidth, bottom - 10), control2: p(24 - halfWidth * 0.56, top))
        path.addCurve(to: p(24 + halfWidth, bottom), control1: p(24 + halfWidth * 0.56, top), control2: p(24 + halfWidth, bottom - 10))
        path.closeSubpath()
        return path
    }

    // MARK: - Safety

    /// Alarm: a solid warning triangle. All clear: a shield with a check.
    func drawSafety() {
        if instrument.isOn {
            drawAlert(tint)
            return
        }
        var shield = Path()
        shield.move(to: p(24, 5))
        shield.addLine(to: p(39, 10.5))
        shield.addLine(to: p(39, 22))
        shield.addCurve(to: p(24, 43), control1: p(39, 32), control2: p(32, 39.5))
        shield.addCurve(to: p(9, 22), control1: p(16, 39.5), control2: p(9, 32))
        shield.addLine(to: p(9, 10.5))
        shield.closeSubpath()
        pen.fill(shield, tint)
        pen.polyline([p(17, 24), p(22, 29), p(31, 18.5)], .white, width: 3.6)
    }

    /// Shared with warning and error messages, so every alarm looks alike.
    func drawAlert(_ color: Color) {
        let triangle = ActivityInstrumentPen.polygon([p(24, 6), p(42, 39), p(6, 39)])
        pen.fill(triangle, color)
        pen.stroke(triangle, color, width: 5)
        pen.line(p(24, 17), p(24, 28.5), .white, width: 3.8)
        pen.dot(p(24, 34), radius: 2.2, .white)
    }

    // MARK: - Lifecycle

    func drawLifecycle() {
        switch instrument.variant {
        case .availability: drawAvailability()
        case .rename: drawPencil()
        case .remove: drawTrash()
        default: drawMembership()
        }
    }

    /// Joined: a green plus. Left: an orange minus.
    private func drawMembership() {
        pen.dot(p(24, 24), radius: 17, tint)
        pen.line(p(15, 24), p(33, 24), .white, width: 3.8)
        if instrument.trend != .falling {
            pen.line(p(24, 15), p(24, 33), .white, width: 3.8)
        }
    }

    /// A presence dot: solid green when online, an empty gray ring offline.
    private func drawAvailability() {
        if instrument.isOn {
            pen.dot(p(24, 24), radius: 9, .green)
        } else {
            pen.ring(p(24, 24), radius: 7.8, .gray, width: 2.6)
        }
    }

    private func drawPencil() {
        let body = ActivityInstrumentPen.rounded(20, 4, 8, 30, radius: 2.5)
            .applying(rotation(45, around: p(24, 24)))
        pen.fill(body, tint)
        let tip = ActivityInstrumentPen.polygon([p(20, 34), p(28, 34), p(24, 42)])
            .applying(rotation(45, around: p(24, 24)))
        pen.fill(tip, tint)
        pen.knockoutLine(p(14.5, 27.5), p(20.5, 33.5), width: 1.6)
    }

    private func drawTrash() {
        pen.line(p(9, 12), p(39, 12), tint)
        pen.line(p(19, 7), p(29, 7), tint)
        pen.fill(ActivityInstrumentPen.rounded(12, 15, 24, 28, radius: 4), tint)
        for x in [19.0, 24.0, 29.0] as [CGFloat] {
            pen.knockoutLine(p(x, 21), p(x, 37), width: 2)
        }
    }
}
