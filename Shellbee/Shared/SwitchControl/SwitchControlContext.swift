import Foundation

struct SwitchControlContext: Equatable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
        let unit: String?
    }

    let stateFeature: Feature?
    let powerFeature: Feature?
    let energyFeature: Feature?
    let voltageFeature: Feature?
    let currentFeature: Feature?

    let isOn: Bool
    let powerValue: Double?
    let energyValue: Double?
    let voltageValue: Double?
    let currentValue: Double?

    var hasPowerMetering: Bool {
        powerValue != nil || energyValue != nil || voltageValue != nil || currentValue != nil
    }

    init?(device: Device, state: [String: JSONValue]) {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattened
        let switchFeatures = exposes.first(where: { $0.type == "switch" })?.features ?? []
        let searchPool = switchFeatures.isEmpty ? flat : switchFeatures.flattened + flat

        let stateFeature = Self.find(in: searchPool, names: ["state"])
        guard stateFeature != nil else { return nil }

        self.stateFeature = stateFeature
        self.powerFeature = Self.find(in: flat, names: ["power"])
        self.energyFeature = Self.find(in: flat, names: ["energy"])
        self.voltageFeature = Self.find(in: flat, names: ["voltage"])
        self.currentFeature = Self.find(in: flat, names: ["current"])

        self.isOn = state[stateFeature?.property ?? "state"]?.stringValue != "OFF"
        self.powerValue = Self.numericValue(flat: flat, names: ["power"], in: state)
        self.energyValue = Self.numericValue(flat: flat, names: ["energy"], in: state)
        self.voltageValue = Self.numericValue(flat: flat, names: ["voltage"], in: state)
        self.currentValue = Self.numericValue(flat: flat, names: ["current"], in: state)
    }

    func togglePayload() -> JSONValue? {
        guard let f = stateFeature, f.isWritable else { return nil }
        return .object([f.property: .string(isOn ? "OFF" : "ON")])
    }

    private static func find(in exposes: [Expose], names: Set<String>) -> Feature? {
        for e in exposes {
            let key = e.name ?? e.property ?? ""
            if names.contains(key) || names.contains(e.property ?? "") {
                return Feature(property: e.property ?? key, isWritable: e.isWritable, unit: e.unit)
            }
        }
        return nil
    }

    private static func numericValue(flat: [Expose], names: Set<String>, in state: [String: JSONValue]) -> Double? {
        guard let feature = find(in: flat, names: names) else { return nil }
        return state[feature.property]?.numberValue
    }
}
