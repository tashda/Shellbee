import SwiftUI

/// A bare symbol for the device property a state change is about. Link
/// Quality fills the Wi-Fi bars to the actual value, so the icon itself
/// carries the reading.
struct ActivityPropertyGlyph: View {
    let property: String
    let value: JSONValue?

    var body: some View {
        if let name = Self.symbolName(for: property) {
            Image(systemName: name, variableValue: variableValue)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var variableValue: Double? {
        guard property == "linkquality", let lqi = value?.numberValue else { return nil }
        return min(max(lqi / DesignTokens.ActivityFeed.maxLinkQuality, 0), 1)
    }

    static func symbolName(for property: String) -> String? {
        switch property {
        case "linkquality": "wifi"
        case "temperature", "local_temperature", "device_temperature": "thermometer.medium"
        case "humidity": "humidity.fill"
        case "pressure": "gauge.with.dots.needle.33percent"
        case "illuminance", "illuminance_lux": "sun.max.fill"
        case "power", "energy": "bolt.fill"
        case "voltage", "current": "bolt"
        case "co2": "carbon.dioxide.cloud.fill"
        case "occupancy", "presence": "figure.walk"
        case "contact": "door.left.hand.open"
        case "water_leak": "drop.fill"
        case "smoke": "smoke.fill"
        case "battery": "battery.75percent"
        case "state": "power"
        case "brightness": "sun.max"
        case "color_temp": "thermometer.sun"
        case "position": "blinds.vertical.open"
        case "action": "hand.tap.fill"
        default: nil
        }
    }
}
