import SwiftUI

struct SensorCard: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode

    private static let skipKeys: Set<String> = ["linkquality", "last_seen", "update", "update_available"]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            let readings = makeReadings()
            if readings.isEmpty {
                Text("No sensor data available")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: DesignTokens.Spacing.md) {
                    ForEach(readings, id: \.label) { reading in
                        SensorReadingTile(reading: reading)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: "sensor.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("Sensor State").font(.headline)
            } else {
                Text("Sensor").font(.headline)
            }
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
            let isTrue = value.boolValue == true || value.stringValue?.lowercased() == "true"
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
            let isTrue = value.boolValue == true || value.stringValue?.lowercased() == "true"
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
        case "pm25", "pm10": return "aqi.high"
        case "illuminance", "illuminance_lux": return "sun.max"
        case "motion", "occupancy": return "figure.walk"
        case "contact": return value.boolValue == true ? "door.sliding.left.hand.open" : "door.sliding.left.hand.closed"
        case "water_leak": return "drop.triangle"
        case "smoke": return "smoke"
        case "gas": return "exclamationmark.triangle"
        case "vibration": return "waveform.path"
        case "battery": return batteryIcon
        case "voltage": return "bolt"
        case "current": return "bolt.ring.closed"
        case "power": return "plug"
        case "energy": return "chart.line.uptrend.xyaxis"
        case "tamper": return "lock.open.trianglebadge.exclamationmark"
        default: return "sensor"
        }
    }

    var tint: Color {
        switch property {
        case "temperature": return .orange
        case "humidity": return .blue
        case "pressure": return .indigo
        case "co2", "pm25", "pm10": return .green
        case "illuminance", "illuminance_lux": return .yellow
        case "motion": return .orange
        case "occupancy": return .purple
        case "contact": return .green
        case "water_leak": return .teal
        case "smoke", "gas": return .secondary
        case "vibration": return .purple
        case "tamper": return .red
        case "battery": return batteryTint
        case "voltage", "current", "power", "energy": return .blue
        default: return .secondary
        }
    }

    var isAlert: Bool {
        switch property {
        case "contact", "water_leak", "smoke", "gas", "vibration", "tamper", "battery_low":
            return value.boolValue == true
        case "battery":
            guard let pct = value.numberValue else { return false }
            return pct < Double(DesignTokens.Threshold.lowBattery)
        default:
            return false
        }
    }

    private func binaryLabel(isTrue: Bool) -> String {
        switch property {
        case "motion": return isTrue ? "Detected" : "Clear"
        case "contact": return isTrue ? "Open" : "Closed"
        case "occupancy": return isTrue ? "Occupied" : "Clear"
        case "water_leak": return isTrue ? "Leak" : "Dry"
        case "smoke": return isTrue ? "Detected" : "Clear"
        case "gas": return isTrue ? "Detected" : "Clear"
        case "vibration": return isTrue ? "Vibrating" : "Still"
        case "tamper": return isTrue ? "Tampered" : "Secure"
        case "battery_low": return isTrue ? "Low" : "OK"
        default: return isTrue ? "True" : "False"
        }
    }

    private var batteryIcon: String {
        guard let pct = value.numberValue else { return "battery.50" }
        return Int(pct).batterySymbol
    }

    private var batteryTint: Color {
        guard let pct = value.numberValue else { return .secondary }
        return Int(pct).batteryColor
    }
}

private struct SensorReadingTile: View {
    let reading: SensorReading

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Image(systemName: reading.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(reading.tint)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(reading.numericDisplayValue)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(reading.isAlert ? Color.red : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let unit = reading.unitDisplay {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(reading.isAlert ? Color.red.opacity(0.7) : Color.secondary)
                        .lineLimit(1)
                }
            }

            Text(reading.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            SensorCard(device: .preview, state: [
                "temperature": .double(21.5),
                "humidity": .double(55),
                "battery": .double(82),
                "motion": .bool(false)
            ], mode: .interactive)
            SensorCard(device: .preview, state: [
                "temperature": .double(21.5),
                "humidity": .double(55),
                "battery": .double(82),
                "motion": .bool(true)
            ], mode: .snapshot)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
