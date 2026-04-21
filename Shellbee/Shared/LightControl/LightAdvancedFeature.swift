import Foundation

struct LightAdvancedFeature: Equatable, Identifiable {
    enum Kind: Equatable {
        case binary(valueOn: JSONValue, valueOff: JSONValue)
        case enumeration([String])
        case numeric(range: ClosedRange<Double>?, step: Double?)
    }

    enum Category {
        case effect, startup, other
    }

    let payloadPath: [String]
    let label: String
    let kind: Kind
    let value: JSONValue?

    var id: String { payloadPath.joined(separator: ".") }

    var displayLabel: String {
        guard let last = payloadPath.last else { return label }
        switch last {
        case "execute_if_off":
            let parent = payloadPath.dropLast().last ?? ""
            if parent.contains("color_temp") { return "Apply Color Temp While Off" }
            if parent.contains("level") || parent.contains("current") { return "Apply Brightness While Off" }
            return "Apply Settings While Off"
        case "color_temp_startup":
            return "Color Temperature"
        case "current_level_startup":
            return "Startup Brightness"
        default:
            let stripped = last.hasSuffix("_startup") ? String(last.dropLast("_startup".count)) : last
            return stripped.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var isColorTemperatureMireds: Bool {
        payloadPath.last == "color_temp_startup"
    }

    var category: Category {
        if payloadPath.last == "effect" { return .effect }
        let isStartup = payloadPath.contains {
            $0.hasSuffix("_startup") || $0 == "power_on_behavior" || $0 == "color_power_on_behavior"
                || $0 == "execute_if_off"
        }
        return isStartup ? .startup : .other
    }

    func payload(_ value: JSONValue) -> JSONValue {
        payload(for: Array(payloadPath[...]), value: value)
    }

    private func payload(for path: [String], value: JSONValue) -> JSONValue {
        guard let key = path.first else {
            return value
        }

        if path.count == 1 {
            return .object([key: value])
        }

        return .object([key: payload(for: Array(path.dropFirst()), value: value)])
    }
}
