import SwiftUI

struct ClimateControlContext: Equatable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
        let range: ClosedRange<Double>?
        let step: Double?
        let values: [String]?
    }

    let temperatureFeature: Feature?
    let heatingSetpointFeature: Feature?
    let coolingSetpointFeature: Feature?
    let systemModeFeature: Feature?
    let runningStateFeature: Feature?
    let fanModeFeature: Feature?
    let presetFeature: Feature?

    let currentTemperature: Double?
    let heatingSetpoint: Double?
    let coolingSetpoint: Double?
    let systemMode: String?
    let runningState: String?
    let fanMode: String?
    let preset: String?

    var displayTemperature: String {
        guard let t = currentTemperature else { return "—" }
        return String(format: "%.1f°", t)
    }

    var activeSetpoint: Double? { heatingSetpoint ?? coolingSetpoint }
    var activeSetpointFeature: Feature? { heatingSetpointFeature ?? coolingSetpointFeature }

    var runningStateLabel: String {
        switch runningState?.lowercased() {
        case "heat", "heating": return "Heating"
        case "cool", "cooling": return "Cooling"
        case "fan", "fan_only": return "Fan"
        case "idle": return "Idle"
        default: return runningState?.capitalized ?? "Idle"
        }
    }

    var runningStateColor: Color {
        switch runningState?.lowercased() {
        case "heat", "heating": return .orange
        case "cool", "cooling": return .blue
        case "fan", "fan_only": return .teal
        default: return .secondary
        }
    }

    init?(device: Device, state: [String: JSONValue]) {
        let exposes = device.definition?.exposes ?? []
        let flat = Self.flatten(exposes)
        let climateFeatures = exposes.first(where: { $0.type == "climate" })?.features ?? flat

        let tempFeature = Self.find(in: climateFeatures, names: ["local_temperature"])
        let heatFeature = Self.find(in: climateFeatures, names: ["occupied_heating_setpoint", "current_heating_setpoint"])
        let coolFeature = Self.find(in: climateFeatures, names: ["occupied_cooling_setpoint", "current_cooling_setpoint"])
        let modeFeature = Self.find(in: climateFeatures, names: ["system_mode"])
        let stateFeature = Self.find(in: climateFeatures, names: ["running_state"])
        let fanFeature   = Self.find(in: climateFeatures, names: ["fan_mode"])
        let presetFeat   = Self.find(in: climateFeatures, names: ["preset"])

        guard tempFeature != nil || heatFeature != nil || modeFeature != nil else { return nil }

        self.temperatureFeature = tempFeature
        self.heatingSetpointFeature = heatFeature
        self.coolingSetpointFeature = coolFeature
        self.systemModeFeature = modeFeature
        self.runningStateFeature = stateFeature
        self.fanModeFeature = fanFeature
        self.presetFeature = presetFeat

        self.currentTemperature = tempFeature.flatMap { state[$0.property]?.numberValue }
        self.heatingSetpoint = heatFeature.flatMap { state[$0.property]?.numberValue }
        self.coolingSetpoint = coolFeature.flatMap { state[$0.property]?.numberValue }
        self.systemMode = modeFeature.flatMap { state[$0.property]?.stringValue }
        self.runningState = stateFeature.flatMap { state[$0.property]?.stringValue }
        self.fanMode = fanFeature.flatMap { state[$0.property]?.stringValue }
        self.preset = presetFeat.flatMap { state[$0.property]?.stringValue }
    }

    func setpointPayload(_ value: Double) -> JSONValue? {
        let f = heatingSetpointFeature ?? coolingSetpointFeature
        guard let f, f.isWritable else { return nil }
        return .object([f.property: .double(value)])
    }

    func systemModePayload(_ mode: String) -> JSONValue? {
        guard let f = systemModeFeature, f.isWritable else { return nil }
        return .object([f.property: .string(mode)])
    }

    private static func flatten(_ exposes: [Expose]) -> [Expose] {
        exposes.flatMap { [$0] + flatten($0.features ?? []) }
    }

    private static func find(in exposes: [Expose], names: Set<String>) -> Feature? {
        for e in exposes {
            let key = e.name ?? e.property ?? ""
            if names.contains(key) || names.contains(e.property ?? "") {
                let range: ClosedRange<Double>? = (e.valueMin != nil && e.valueMax != nil)
                    ? (e.valueMin! ... e.valueMax!) : nil
                return Feature(property: e.property ?? key, isWritable: e.isWritable,
                               range: range, step: e.valueStep, values: e.values)
            }
        }
        return nil
    }
}
