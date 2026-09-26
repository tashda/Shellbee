import SwiftUI

/// What an air purifier reports: PM2.5, the air quality word, and filter
/// health. Shared by the fan card header and the reading sections.
struct FanAirReadings {
    let context: FanControlContext

    static let claimedProperties: Set<String> = [
        "pm25", "air_quality", "replace_filter", "filter_age", "device_age"
    ]

    private var pm25Expose: Expose? { context.extras.first { $0.property == "pm25" } }
    private var airQualityExpose: Expose? { context.extras.first { $0.property == "air_quality" } }

    var hasAirSensors: Bool { airQualityExpose != nil || pm25Expose != nil }

    /// Purifiers report -1 while the sensor isn't running; treat it as missing.
    var pm25: Double? {
        guard let p = pm25Expose?.property, let v = context.state[p]?.numberValue, v >= 0 else { return nil }
        return v
    }

    var pm25Unit: String { pm25Expose?.unit ?? "µg/m³" }

    var airQuality: String? {
        guard let p = airQualityExpose?.property,
              let v = context.state[p]?.stringValue, v.lowercased() != "unknown" else { return nil }
        return v
    }

    /// AQI colour; only moderate or worse air is coloured on screen.
    var airQualityTint: Color {
        if let airQuality {
            switch airQuality.lowercased() {
            case "excellent": return .green
            case "good": return .mint
            case "moderate", "fair": return .yellow
            case "poor": return .orange
            case "unhealthy", "very_poor", "very poor", "hazardous", "bad": return .red
            default: break
            }
        }
        if let pm25 {
            switch pm25 {
            case ..<12: return .green
            case ..<35: return .mint
            case ..<55: return .yellow
            case ..<150: return .orange
            default: return .red
            }
        }
        return .teal
    }

    var airQualityNeedsAttention: Bool {
        [Color.yellow, .orange, .red].contains(airQualityTint)
    }

    var hasFilter: Bool {
        context.extras.contains { ["replace_filter", "filter_age", "device_age"].contains($0.property ?? "") }
    }

    var needsFilterReplacement: Bool {
        guard let e = context.extras.first(where: { $0.property == "replace_filter" }),
              let p = e.property else { return false }
        let v = context.state[p]
        if v == e.valueOn { return true }
        if v == e.valueOff { return false }
        return v?.boolValue ?? false
    }

    var filterAge: Double? { context.state["filter_age"]?.numberValue }
    var deviceAge: Double? { context.state["device_age"]?.numberValue }

    static func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// Air Quality and Filter as native List sections beneath the purifier
/// card: readings are rows, the card keeps only the controls.
struct FanReadingsSections: View {
    let context: FanControlContext

    private var readings: FanAirReadings { FanAirReadings(context: context) }

    var body: some View {
        if readings.pm25 != nil || readings.airQuality != nil {
            Section("Air Quality") {
                if let pm25 = readings.pm25 {
                    LabeledContent("PM2.5") {
                        Text("\(Int(pm25.rounded())) \(readings.pm25Unit)").monospacedDigit()
                    }
                }
                if let airQuality = readings.airQuality {
                    LabeledContent("Air Quality") {
                        Text(FanAirReadings.prettify(airQuality))
                            .foregroundStyle(readings.airQualityNeedsAttention ? readings.airQualityTint : .secondary)
                    }
                }
            }
        }
        if readings.hasFilter {
            Section("Filter") {
                LabeledContent("Status") {
                    Text(readings.needsFilterReplacement ? "Replace" : "Healthy")
                        .foregroundStyle(readings.needsFilterReplacement ? .orange : .secondary)
                }
                if let filterAge = readings.filterAge {
                    LabeledContent("Filter Age") { Text(Self.duration(filterAge)) }
                }
                if let deviceAge = readings.deviceAge {
                    LabeledContent("Device Age") { Text(Self.duration(deviceAge)) }
                }
            }
        }
    }

    /// z2m reports ages in minutes; rows have room to write them out.
    private static func duration(_ minutes: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.year, .month, .day, .hour, .minute]
        return formatter.string(from: minutes * 60) ?? "\(Int(minutes)) min"
    }
}
