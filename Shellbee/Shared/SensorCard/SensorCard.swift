import SwiftUI

struct SensorCard: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode

    private static let skipKeys: Set<String> = ["linkquality", "last_seen", "update", "update_available", "battery", "battery_low"]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if mode == .snapshot {
                header
            }
            let readings = makeReadings()
            if readings.isEmpty {
                Text("No sensor data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                readingsGrid(readings)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private func readingsGrid(_ readings: [SensorReading]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading),
            GridItem(.flexible(), spacing: DesignTokens.Spacing.lg, alignment: .topLeading)
        ]
        return LazyVGrid(columns: columns,
                         alignment: .leading,
                         spacing: DesignTokens.Spacing.xl) {
            ForEach(readings, id: \.label) { reading in
                SensorReadingTile(reading: reading)
            }
        }
    }

    private var header: some View {
        // NOTE: 12pt eyebrow vs 11pt elsewhere — see #36.A.
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "sensor.fill")
                .font(DesignTokens.Typography.eyebrowIconLarge)
                .foregroundStyle(.tint)
            Text("Sensor")
                .font(DesignTokens.Typography.eyebrowLabelLarge)
                .tracking(DesignTokens.Typography.eyebrowTrackingLoose)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    static func hasReadings(device: Device, state: [String: JSONValue]) -> Bool {
        let flat = device.definition?.exposes.flatMap { [$0] + ($0.features ?? []) } ?? []
        return flat.contains { expose in
            let prop = expose.property ?? expose.name ?? ""
            guard !skipKeys.contains(prop), expose.isReadable, !expose.isWritable else { return false }
            guard expose.type == "numeric" || expose.type == "binary" else { return false }
            return state[prop] != nil
        }
    }

    private func makeReadings() -> [SensorReading] {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattened
        return flat.compactMap { expose in
            let prop = expose.property ?? expose.name ?? ""
            guard !Self.skipKeys.contains(prop), expose.isReadable, !expose.isWritable else { return nil }
            guard expose.type == "numeric" || expose.type == "binary" else { return nil }
            guard let value = state[prop] else { return nil }
            return SensorReading(expose: expose, property: prop, value: value)
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

    var numericDisplayValue: String {
        switch expose.type {
        case "binary":
            return binaryLabel(isTrue: isTrue)
        case "numeric":
            guard let num = value.numberValue else { return value.stringified }
            return num.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", num)
                : String(format: "%.1f", num)
        default:
            return value.stringified
        }
    }

    var unitDisplay: String? {
        guard expose.type == "numeric" else { return nil }
        return expose.unit
    }

    var icon: String {
        switch property {
        case "temperature": return "thermometer.medium"
        case "humidity": return "humidity"
        case "pressure": return "gauge.medium"
        case "co2": return "aqi.medium"
        case "carbon_monoxide": return "aqi.high"
        case "pm25", "pm10": return "aqi.high"
        case "illuminance", "illuminance_lux": return "sun.max"
        case "motion", "occupancy", "presence": return "figure.walk"
        case "moving": return "arrow.left.arrow.right"
        case "contact": return isTrue ? "door.sliding.left.hand.closed" : "door.sliding.left.hand.open"
        case "window_open": return isTrue ? "window.vertical.open" : "window.vertical.closed"
        case "water_leak": return "drop.triangle"
        case "smoke": return "smoke"
        case "gas": return "exclamationmark.triangle"
        case "vibration": return "waveform.path"
        case "voltage": return "bolt"
        case "current": return "bolt.ring.closed"
        case "power": return "plug"
        case "energy": return "chart.line.uptrend.xyaxis"
        case "tamper": return "lock.open.trianglebadge.exclamationmark"
        case "alarm", "sos": return "exclamationmark.triangle.fill"
        case "child_lock": return "lock.fill"
        default: return "sensor"
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

    /// Color of the *value* text. Numerics stay primary. Binary state sensors
    /// get a state-driven color: alarm-class red, "open/triggered" orange,
    /// "presence detected" green. Inactive binary stays secondary.
    var valueColor: Color {
        guard expose.type == "binary" else { return .primary }
        if !binaryActive { return .secondary }
        switch property {
        case "water_leak", "smoke", "gas", "carbon_monoxide", "tamper", "sos", "alarm":
            return .red
        case "contact", "window_open", "vibration", "moving", "child_lock":
            return .orange
        case "motion", "occupancy", "presence":
            return .green
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

private struct SensorReadingTile: View {
    let reading: SensorReading

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: reading.icon)
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(reading.label)
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(reading.numericDisplayValue)
                    .font(DesignTokens.Typography.metricValue)
                    .monospacedDigit()
                    .foregroundStyle(reading.valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorTight)
                if let unit = reading.unitDisplay {
                    Text(unit)
                        .font(DesignTokens.Typography.metricUnit)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            SensorCard(device: .preview, state: [
                "temperature": .double(21.5),
                "humidity": .double(55),
                "occupancy": .bool(true),
                "contact": .bool(false)
            ], mode: .interactive)
            SensorCard(device: .preview, state: [
                "temperature": .double(21.5),
                "humidity": .double(55),
                "contact": .bool(true),
                "water_leak": .bool(true),
                "motion": .bool(true),
                "tamper": .bool(false)
            ], mode: .snapshot)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
