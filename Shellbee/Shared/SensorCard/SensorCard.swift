import SwiftUI

/// A sensor's readings as native List sections: Readings, with when it
/// last reported as the footer, then Diagnostics for the values z2m marks
/// as diagnostic (device temperature, voltage, power outage count).
/// Place inside an inset-grouped `List`.
struct SensorSections: View {
    let device: Device
    let state: [String: JSONValue]

    private static let skipKeys: Set<String> = ["linkquality", "last_seen", "update", "update_available", "battery", "battery_low"]

    var body: some View {
        let readings = Self.readings(device: device, state: state)
        let primary = readings.filter { !isDiagnostic($0) }
        let diagnostics = readings.filter(isDiagnostic)

        if !primary.isEmpty {
            Section {
                ForEach(primary, id: \.property) { SensorReadingRow(reading: $0) }
            } header: {
                Text("Readings")
            } footer: {
                if let updated = DeviceStatus.lastSeenText(state.lastSeen) {
                    Text("Updated \(updated)")
                }
            }
        }
        if !diagnostics.isEmpty {
            Section("Diagnostics") {
                ForEach(diagnostics, id: \.property) { SensorReadingRow(reading: $0) }
            }
        }
    }

    private func isDiagnostic(_ reading: SensorReading) -> Bool {
        // A battery sensor's voltage is diagnostic even when z2m doesn't say so.
        reading.expose.isDiagnostic || (reading.expose.category == nil && reading.property == "voltage")
    }

    static func hasReadings(device: Device, state: [String: JSONValue]) -> Bool {
        !readings(device: device, state: state).isEmpty
    }

    /// Properties these sections show, so the settings below skip them.
    static func readingProperties(device: Device, state: [String: JSONValue]) -> Set<String> {
        Set(readings(device: device, state: state).map(\.property))
    }

    private static func readings(device: Device, state: [String: JSONValue]) -> [SensorReading] {
        (device.definition?.exposes ?? []).flattened.compactMap { expose in
            let prop = expose.property ?? expose.name ?? ""
            guard !skipKeys.contains(prop), expose.isReadable, !expose.isWritable else { return nil }
            guard expose.type == "numeric" || expose.type == "binary" else { return nil }
            guard let value = state[prop] else { return nil }
            return SensorReading(expose: expose, property: prop, value: value)
        }
    }
}

private struct SensorReadingRow: View {
    let reading: SensorReading

    var body: some View {
        LabeledContent {
            Text(reading.displayValue)
                .monospacedDigit()
                .foregroundStyle(reading.valueColor == .primary ? .secondary : reading.valueColor)
        } label: {
            Text(reading.label)
        }
    }
}

struct SensorReading {
    let expose: Expose
    let property: String
    let value: JSONValue

    var label: String {
        expose.label ?? property.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var displayValue: String {
        switch expose.type {
        case "binary":
            return binaryLabel(isTrue: isTrue)
        case "numeric":
            guard let num = value.numberValue else { return value.stringified }
            let formatted = num.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", num)
                : String(format: "%.1f", num)
            return expose.unit.map { "\(formatted) \($0)" } ?? formatted
        default:
            return value.stringified
        }
    }

    /// Whether this binary reading represents an active/triggered state worth
    /// drawing the user's eye to. Used to color the value text only — the icon
    /// and label stay monochrome.
    var binaryActive: Bool {
        guard expose.type == "binary" else { return false }
        if property == "contact" { return !isTrue }
        return isTrue
    }

    /// Color of the *value* text. Numerics and presence stay primary; colour
    /// is kept for states that need attention: alarm-class red and
    /// "open/triggered" orange. Inactive binary stays secondary.
    var valueColor: Color {
        guard expose.type == "binary" else { return .primary }
        if !binaryActive { return .secondary }
        switch property {
        case "water_leak", "smoke", "gas", "carbon_monoxide", "tamper", "sos", "alarm":
            return .red
        case "contact", "window_open", "vibration", "moving", "child_lock":
            return .orange
        default:
            return .primary
        }
    }

    private func binaryLabel(isTrue: Bool) -> String {
        switch property {
        case "motion": return isTrue ? "Detected" : "Clear"
        case "contact": return isTrue ? "Closed" : "Open"
        case "window_open": return isTrue ? "Open" : "Closed"
        case "occupancy", "presence": return isTrue ? "Occupied" : "Clear"
        case "moving": return isTrue ? "Moving" : "Still"
        case "water_leak": return isTrue ? "Leak" : "Dry"
        case "smoke": return isTrue ? "Detected" : "Clear"
        case "gas": return isTrue ? "Detected" : "Clear"
        case "carbon_monoxide": return isTrue ? "Detected" : "Clear"
        case "vibration": return isTrue ? "Vibrating" : "Still"
        case "tamper": return isTrue ? "Tampered" : "Secure"
        case "alarm": return isTrue ? "Alarm" : "Clear"
        case "sos": return isTrue ? "SOS" : "Clear"
        case "child_lock": return isTrue ? "Locked" : "Unlocked"
        default: return isTrue ? "On" : "Off"
        }
    }

    private var isTrue: Bool {
        value.boolValue == true || value.stringValue?.lowercased() == "true"
    }

}

#Preview {
    List {
        SensorSections(device: .preview, state: [
            "temperature": .double(21.5),
            "humidity": .double(55),
            "occupancy": .bool(false),
            "water_leak": .bool(true)
        ])
    }
}
