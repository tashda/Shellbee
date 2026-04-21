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

    private func makeReadings() -> [SensorReading] {
        let exposes = device.definition?.exposes ?? []
        let flat = flatten(exposes)
        return flat.compactMap { expose in
            let prop = expose.property ?? expose.name ?? ""
            guard !Self.skipKeys.contains(prop), expose.isReadable, !expose.isWritable else { return nil }
            guard expose.type == "numeric" || expose.type == "binary" else { return nil }
            guard let value = state[prop] else { return nil }
            return SensorReading(expose: expose, property: prop, value: value)
        }
    }

    private func flatten(_ exposes: [Expose]) -> [Expose] {
        exposes.flatMap { [$0] + flatten($0.features ?? []) }
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
        case "motion", "occupancy": return value.boolValue == true ? .orange : .secondary
        case "contact": return value.boolValue == true ? .red : .green
        case "water_leak", "gas", "smoke": return (value.boolValue == true) ? .red : .secondary
        case "battery": return batteryTint
        case "voltage", "current", "power", "energy": return .blue
        default: return .secondary
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
        default: return isTrue ? "On" : "Off"
        }
    }

    private var batteryIcon: String {
        guard let pct = value.numberValue else { return "battery.50" }
        if pct > 75 { return "battery.100" }
        if pct > 40 { return "battery.50" }
        if pct > 10 { return "battery.25" }
        return "battery.0"
    }

    private var batteryTint: Color {
        guard let pct = value.numberValue else { return .secondary }
        return pct < Double(DesignTokens.Threshold.lowBattery) ? .red : .green
    }
}

private struct SensorReadingTile: View {
    let reading: SensorReading

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: reading.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(reading.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.displayValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(reading.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
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
