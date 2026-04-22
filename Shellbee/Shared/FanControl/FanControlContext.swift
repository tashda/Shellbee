import Foundation

struct FanControlContext: Equatable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
        let values: [String]?
        let range: ClosedRange<Double>?
    }

    let stateFeature: Feature?
    let fanModeFeature: Feature?
    let speedFeature: Feature?

    let isOn: Bool
    let fanMode: String?
    let speedPercent: Double?

    init?(device: Device, state: [String: JSONValue]) {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattened
        let fanFeatures = exposes.first(where: { $0.type == "fan" })?.features ?? flat

        let stateFeature = Self.find(in: fanFeatures + flat, names: ["state"])
        guard stateFeature != nil else { return nil }

        self.stateFeature = stateFeature
        self.fanModeFeature = Self.find(in: fanFeatures + flat, names: ["fan_mode", "mode"])
        self.speedFeature = Self.find(in: fanFeatures + flat, names: ["fan_speed_percent", "speed"])

        self.isOn = state[stateFeature?.property ?? "state"]?.stringValue != "OFF"
        self.fanMode = self.fanModeFeature.flatMap { state[$0.property]?.stringValue }
        self.speedPercent = self.speedFeature.flatMap { state[$0.property]?.numberValue }
    }

    func togglePayload() -> JSONValue? {
        guard let f = stateFeature, f.isWritable else { return nil }
        return .object([f.property: .string(isOn ? "OFF" : "ON")])
    }

    func fanModePayload(_ mode: String) -> JSONValue? {
        guard let f = fanModeFeature, f.isWritable else { return nil }
        return .object([f.property: .string(mode)])
    }

    private static func find(in exposes: [Expose], names: Set<String>) -> Feature? {
        for e in exposes {
            let key = e.name ?? e.property ?? ""
            if names.contains(key) || names.contains(e.property ?? "") {
                let range: ClosedRange<Double>? = (e.valueMin != nil && e.valueMax != nil)
                    ? (e.valueMin! ... e.valueMax!) : nil
                return Feature(property: e.property ?? key, isWritable: e.isWritable,
                               values: e.values, range: range)
            }
        }
        return nil
    }
}
