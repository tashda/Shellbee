import SwiftUI

/// A compact, bespoke micro-visual for an Activity event. It deliberately
/// avoids icon wells: the mark itself carries the value, state, or event.
struct ActivityInstrumentView: View {
    let instrument: ActivityInstrument
    var size: CGFloat = DesignTokens.ActivityInstrument.size

    var body: some View {
        Canvas { context, canvasSize in
            var scaled = context
            let grid = DesignTokens.ActivityInstrument.grid
            scaled.scaleBy(x: canvasSize.width / grid, y: canvasSize.height / grid)
            ActivityInstrumentDrawing(instrument: instrument, pen: ActivityInstrumentPen(context: scaled)).draw()
        }
        .frame(width: size, height: size)
        // Cut-outs erase to transparent, so the Canvas needs its own layer.
        .compositingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(instrument.accessibilityDescription)
    }
}

/// Dispatches an instrument to its drawing. The drawings live in extensions
/// grouped the way the Activity review grouped them: values, states, events.
struct ActivityInstrumentDrawing {
    let instrument: ActivityInstrument
    let pen: ActivityInstrumentPen

    var tint: Color { instrument.tint }
    var value: Double { instrument.normalizedValue }

    func draw() {
        switch instrument.kind {
        case .level: drawLevel()
        case .binary: drawBinary()
        case .trend: drawTrend()
        case .temperature: drawTemperature()
        case .humidity: drawHumidity()
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
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.lg) {
        ActivityInstrumentView(instrument: .init(kind: .level, normalizedValue: 0.8))
        ActivityInstrumentView(instrument: .init(kind: .binary, normalizedValue: 1))
        ActivityInstrumentView(instrument: .init(kind: .battery, normalizedValue: 0.18))
        ActivityInstrumentView(instrument: .init(kind: .safety, normalizedValue: 1, severity: .failure))
    }
    .padding()
}
