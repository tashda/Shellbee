import SwiftUI

struct LightControlContext: Equatable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
        let range: ClosedRange<Double>?
        let step: Double?
    }

    let power: Feature?
    let brightness: Feature?
    let colorTemperature: Feature?
    let color: Feature?
    let advancedFeatures: [LightAdvancedFeature]
    let isOn: Bool
    let brightnessValue: Double?
    let colorTemperatureValue: Double?
    let colorMode: String?
    let displayColor: Color

    var supportsWhiteControls: Bool { colorTemperature != nil }
    var supportsColorControls: Bool { color != nil }
    var hasAdvancedFeatures: Bool { !advancedFeatures.isEmpty }

    var effectFeature: LightAdvancedFeature? {
        advancedFeatures.first { $0.category == .effect }
    }

    var startupFeatures: [LightAdvancedFeature] {
        advancedFeatures.filter { $0.category == .startup }
    }

    var otherAdvancedFeatures: [LightAdvancedFeature] {
        advancedFeatures.filter { $0.category == .other }
    }

    init?(device: Device, state: [String: JSONValue]) {
        let exposures = device.definition?.exposes ?? []
        let power = Self.findFeature(in: exposures, names: ["state"])
        let brightness = Self.findFeature(in: exposures, names: ["brightness"])
        let colorTemperature = Self.findFeature(in: exposures, names: ["color_temp"])
        let color = Self.findColorFeature(in: exposures)

        let brightnessValue = Self.numberValue(for: brightness?.property, in: state)
        let colorTemperatureValue = Self.numberValue(for: colorTemperature?.property, in: state)
        let colorMode = state["color_mode"]?.stringValue

        guard power != nil || brightness != nil || colorTemperature != nil || color != nil || colorMode != nil else {
            return nil
        }

        self.power = power
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.color = color
        self.advancedFeatures = Self.collectAdvancedFeatures(from: exposures, state: .object(state))
        self.isOn = state[power?.property ?? "state"]?.stringValue != "OFF"
        self.brightnessValue = brightnessValue
        self.colorTemperatureValue = colorTemperatureValue
        self.colorMode = colorMode
        self.displayColor = LightDisplayColor.resolve(
            colorValue: state[color?.property ?? "color"],
            colorTemperature: colorTemperatureValue,
            colorMode: colorMode
        )
    }

    var brightnessPercent: Int {
        guard let brightness else { return isOn ? 100 : 0 }
        let current = brightnessValue ?? (isOn ? brightness.range?.upperBound ?? 254 : 0)
        let range = brightness.range ?? 0...254
        guard range.upperBound > range.lowerBound else { return 0 }
        let progress = (current - range.lowerBound) / (range.upperBound - range.lowerBound)
        return Int((progress * 100).rounded())
    }

    func powerPayload(isOn: Bool) -> JSONValue? {
        guard let power, power.isWritable else { return nil }
        return .object([power.property: .string(isOn ? "ON" : "OFF")])
    }

    func brightnessCommandPayload(_ value: Double) -> JSONValue? {
        guard let brightness, brightness.isWritable else { return nil }

        if value <= 0 {
            return powerPayload(isOn: false) ?? .object([brightness.property: .int(0)])
        }

        var payload: [String: JSONValue] = [brightness.property: .int(Int(value.rounded()))]
        if let power, power.isWritable {
            payload[power.property] = .string("ON")
        }

        return .object(payload)
    }

    func suggestedOnBrightnessValue() -> Double {
        if let brightnessValue, brightnessValue > 0 {
            return brightnessValue
        }

        if let brightnessRange = brightness?.range {
            return max(brightnessRange.lowerBound + 1, min(160, brightnessRange.upperBound))
        }

        return 160
    }

    func colorTemperaturePayload(_ value: Double) -> JSONValue? {
        guard let colorTemperature, colorTemperature.isWritable else { return nil }
        return .object([colorTemperature.property: .int(Int(value.rounded()))])
    }

    func colorPayload(hex: String) -> JSONValue? {
        guard let color, color.isWritable else { return nil }

        var payload: [String: JSONValue] = [color.property: .object(["hex": .string(hex)])]
        if let power, power.isWritable {
            payload[power.property] = .string("ON")
        }

        return .object(payload)
    }

    private static let primaryFeatureNames: Set<String> = [
        "state",
        "brightness",
        "color_temp",
        "color",
        "color_xy",
        "color_hs",
        "identify"
    ]

    private static func findFeature(in exposes: [Expose], names: Set<String>) -> Feature? {
        for expose in exposes {
            if let name = expose.name, names.contains(name) {
                return Feature(
                    property: expose.property ?? name,
                    isWritable: expose.isWritable,
                    range: Self.range(for: expose),
                    step: expose.valueStep
                )
            }

            if let property = expose.property, names.contains(property) {
                return Feature(
                    property: property,
                    isWritable: expose.isWritable,
                    range: Self.range(for: expose),
                    step: expose.valueStep
                )
            }

            if let feature = findFeature(in: expose.features ?? [], names: names) {
                return feature
            }
        }

        return nil
    }

    private static func findColorFeature(in exposes: [Expose]) -> Feature? {
        if let feature = findFeature(in: exposes, names: ["color_xy", "color_hs", "color"]) {
            let property = ["color_xy", "color_hs"].contains(feature.property) ? "color" : feature.property
            return Feature(property: property, isWritable: feature.isWritable, range: nil, step: nil)
        }

        return nil
    }

    private static func collectAdvancedFeatures(from exposes: [Expose], state: JSONValue, parents: [String] = []) -> [LightAdvancedFeature] {
        var collected: [LightAdvancedFeature] = []
        var seen: Set<String> = []

        for expose in exposes {
            let property = expose.property ?? expose.name
            let nextParents = property.map { parents + [$0] } ?? parents

            if let feature = advancedFeature(from: expose, state: state, parents: parents) {
                if seen.insert(feature.id).inserted {
                    collected.append(feature)
                }
            }

            if let children = expose.features {
                let nestedState = property.flatMap { state.object?[$0] } ?? state
                let nested = collectAdvancedFeatures(from: children, state: nestedState, parents: nextParents)
                for feature in nested where seen.insert(feature.id).inserted {
                    collected.append(feature)
                }
            }
        }

        return collected
    }

    private static func advancedFeature(from expose: Expose, state: JSONValue, parents: [String]) -> LightAdvancedFeature? {
        guard expose.isWritable else { return nil }
        guard !parents.contains("color") else { return nil }

        let name = expose.name ?? expose.property ?? ""
        guard !primaryFeatureNames.contains(name) else { return nil }
        guard let property = expose.property ?? expose.name else { return nil }

        let payloadPath = parents + [property]
        let label = expose.label ?? property.replacingOccurrences(of: "_", with: " ").capitalized
        let currentValue = state.value(at: [property])

        switch expose.type {
        case "binary":
            guard let valueOn = expose.valueOn, let valueOff = expose.valueOff else { return nil }
            return LightAdvancedFeature(
                payloadPath: payloadPath,
                label: label,
                kind: .binary(valueOn: valueOn, valueOff: valueOff),
                value: currentValue
            )
        case "enum":
            guard let values = expose.values, !values.isEmpty else { return nil }
            return LightAdvancedFeature(
                payloadPath: payloadPath,
                label: label,
                kind: .enumeration(values),
                value: currentValue
            )
        case "numeric":
            return LightAdvancedFeature(
                payloadPath: payloadPath,
                label: label,
                kind: .numeric(range: range(for: expose), step: expose.valueStep),
                value: currentValue
            )
        default:
            return nil
        }
    }

    private static func range(for expose: Expose) -> ClosedRange<Double>? {
        guard let lower = expose.valueMin, let upper = expose.valueMax else { return nil }
        return lower...upper
    }

    private static func numberValue(for property: String?, in state: [String: JSONValue]) -> Double? {
        guard let property else { return nil }
        return state[property]?.numberValue
    }
}
