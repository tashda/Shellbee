import Foundation

struct SwitchControlContext: Equatable, Identifiable {
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

    let endpointLabel: String?

    var id: String { stateFeature?.property ?? endpointLabel ?? "switch" }

    var hasPowerMetering: Bool {
        powerValue != nil || energyValue != nil || voltageValue != nil || currentValue != nil
    }

    init?(device: Device, state: [String: JSONValue]) {
        self.init(device: device, state: state, switchBlock: nil, includeMetering: true)
    }

    /// Builds one context per top-level `switch` expose. Multi-endpoint devices
    /// (e.g. Aqara QBKG12LM, AUT000069) emit one switch block per relay; this
    /// returns one context per block so the UI can render a toggle for each.
    /// Power/energy metering, when present, is attached only to the first
    /// context — Z2M reports those at device level (see `multiEndpointSkip`).
    static func contexts(for device: Device, state: [String: JSONValue]) -> [SwitchControlContext] {
        let switchBlocks = (device.definition?.exposes ?? []).filter { $0.type == "switch" }
        if switchBlocks.count <= 1 {
            return SwitchControlContext(device: device, state: state).map { [$0] } ?? []
        }
        return switchBlocks.enumerated().compactMap { idx, block in
            SwitchControlContext(device: device, state: state, switchBlock: block, includeMetering: idx == 0)
        }
    }

    private init?(device: Device, state: [String: JSONValue], switchBlock: Expose?, includeMetering: Bool) {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattened
        let scopedFeatures: [Expose]
        if let block = switchBlock {
            scopedFeatures = (block.features ?? []).flattened
        } else {
            let switchFeatures = exposes.first(where: { $0.type == "switch" })?.features ?? []
            scopedFeatures = switchFeatures.isEmpty ? flat : switchFeatures.flattened + flat
        }

        guard let stateFeature = Self.find(in: scopedFeatures, names: ["state"]) else { return nil }

        self.stateFeature = stateFeature
        self.powerFeature = includeMetering ? Self.find(in: flat, names: ["power"]) : nil
        self.energyFeature = includeMetering ? Self.find(in: flat, names: ["energy"]) : nil
        self.voltageFeature = includeMetering ? Self.find(in: flat, names: ["voltage"]) : nil
        self.currentFeature = includeMetering ? Self.find(in: flat, names: ["current"]) : nil

        self.isOn = state[stateFeature.property]?.stringValue != "OFF"
        self.powerValue = includeMetering ? Self.numericValue(flat: flat, names: ["power"], in: state) : nil
        self.energyValue = includeMetering ? Self.numericValue(flat: flat, names: ["energy"], in: state) : nil
        self.voltageValue = includeMetering ? Self.numericValue(flat: flat, names: ["voltage"], in: state) : nil
        self.currentValue = includeMetering ? Self.numericValue(flat: flat, names: ["current"], in: state) : nil

        self.endpointLabel = switchBlock?.endpoint.map(Self.formatEndpoint)
    }

    func togglePayload() -> JSONValue? {
        guard let f = stateFeature, f.isWritable else { return nil }
        return .object([f.property: .string(isOn ? "OFF" : "ON")])
    }

    private static func formatEndpoint(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
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
