import SwiftUI

struct LightControlContext: Equatable, Identifiable {
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
    /// Raw `color` object payload (if any). Stored so `isColorMode` can fall
    /// back to "is there a real color value" when `color_mode` lies — a known
    /// failure mode on Hue lights with `hue_native_control` enabled, where
    /// the bulb reports the equivalent color temperature alongside a fresh
    /// color object during color changes.
    let colorPayload: JSONValue?
    let displayColor: Color
    let endpointLabel: String?

    /// True when the snapshot should render the color surface (Color row,
    /// Color picker, color tint) rather than the color-temperature surface.
    /// Authoritative signal in priority order:
    ///   1. `color_mode` is explicitly `"xy"` or `"hs"` (z2m's spec values).
    ///   2. The `color` payload carries recognizable sub-fields (x/y, h/s,
    ///      hue/saturation, or r/g/b) — wins even when `color_mode` says
    ///      `"color_temp"`, because some Hue firmware paths report stale
    ///      mode while the bulb is actually rendering a color.
    var isColorMode: Bool {
        if colorMode == "xy" || colorMode == "hs" { return true }
        return colorPayload.flatMap(Self.colorObjectIsRecognizable) ?? false
    }

    /// True when a usable color-temperature reading exists. Suppressed when
    /// `isColorMode` already won — Hue native control publishes a stale
    /// `color_temp` alongside a real color and we don't want the snapshot
    /// to claim "Color Temperature 6535 K" while the bulb is rendering green.
    var hasColorTemperatureReading: Bool {
        guard colorTemperatureValue != nil else { return false }
        return !isColorMode
    }

    private static func colorObjectIsRecognizable(_ value: JSONValue) -> Bool {
        guard let object = value.object else { return false }
        let xy = object["x"]?.numberValue != nil && object["y"]?.numberValue != nil
        let hs = (object["hue"]?.numberValue ?? object["h"]?.numberValue) != nil
            && (object["saturation"]?.numberValue ?? object["s"]?.numberValue) != nil
        let rgb = object["r"]?.numberValue != nil
            && object["g"]?.numberValue != nil
            && object["b"]?.numberValue != nil
        return xy || hs || rgb
    }

    var id: String { power?.property ?? brightness?.property ?? endpointLabel ?? "light" }

    var supportsWhiteControls: Bool { colorTemperature != nil }
    var supportsColorControls: Bool { color != nil }
    var hasAdvancedFeatures: Bool { !advancedFeatures.isEmpty }

    var effectFeature: LightAdvancedFeature? {
        advancedFeatures.first { $0.category == .effect }
    }

    var startupFeatures: [LightAdvancedFeature] {
        let filtered = advancedFeatures.filter { $0.category == .startup }
        return filtered.sorted { Self.startupSortKey($0) < Self.startupSortKey($1) }
    }

    /// Lower keys sort first. Power-On Behavior is the headline setting and
    /// must lead; the per-attribute startup defaults follow in a natural
    /// "what does it do, then what does it look like" order.
    private static func startupSortKey(_ feature: LightAdvancedFeature) -> Int {
        guard let last = feature.payloadPath.last else { return 99 }
        switch last {
        case "power_on_behavior":               return 0
        case "color_power_on_behavior":         return 1
        case "state_startup":                   return 2
        case "current_level_startup":           return 3
        case "color_temp_startup":              return 4
        case "hue_startup", "saturation_startup": return 5
        case "execute_if_off":                  return 9
        default:
            return last.hasSuffix("_startup") ? 6 : 8
        }
    }

    var otherAdvancedFeatures: [LightAdvancedFeature] {
        advancedFeatures.filter { $0.category == .other }
    }

    init?(device: Device, state: [String: JSONValue]) {
        self.init(device: device, state: state, lightBlock: nil)
    }

    /// Builds one context per top-level `light` expose. Multi-endpoint dimmers
    /// (e.g. QS-Zigbee-D02-TRIAC-2C-LN) emit one block per channel with
    /// `state_l1`/`brightness_l1` etc., needing a separate card per channel.
    static func contexts(for device: Device, state: [String: JSONValue]) -> [LightControlContext] {
        let lightBlocks = (device.definition?.exposes ?? []).filter { $0.type == "light" }
        if lightBlocks.count <= 1 {
            return LightControlContext(device: device, state: state).map { [$0] } ?? []
        }
        return lightBlocks.compactMap { LightControlContext(device: device, state: state, lightBlock: $0) }
    }

    private init?(device: Device, state: [String: JSONValue], lightBlock: Expose?) {
        let allExposures = device.definition?.exposes ?? []
        let scope: [Expose] = lightBlock.map { [$0] } ?? allExposures
        let power = Self.findFeature(in: scope, names: ["state"])
        let brightness = Self.findFeature(in: scope, names: ["brightness"])
        let colorTemperature = Self.findFeature(in: scope, names: ["color_temp"])
        let color = Self.findColorFeature(in: scope)

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
        self.advancedFeatures = Self.collectAdvancedFeatures(from: scope, state: .object(state))
        self.isOn = state[power?.property ?? "state"]?.stringValue != "OFF"
        self.brightnessValue = brightnessValue
        self.colorTemperatureValue = colorTemperatureValue
        self.colorMode = colorMode
        let colorPayload = state[color?.property ?? "color"]
        self.colorPayload = colorPayload
        self.displayColor = LightDisplayColor.resolve(
            colorValue: colorPayload,
            colorTemperature: colorTemperatureValue,
            colorMode: colorMode
        )
        self.endpointLabel = lightBlock?.endpoint.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
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
