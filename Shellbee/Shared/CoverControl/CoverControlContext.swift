import Foundation

struct CoverControlContext: Equatable, Identifiable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
        let range: ClosedRange<Double>?
    }

    let stateFeature: Feature?
    let positionFeature: Feature?
    let tiltFeature: Feature?

    let stateValue: String?
    let positionValue: Double?
    let tiltValue: Double?

    let endpointLabel: String?

    var id: String { stateFeature?.property ?? positionFeature?.property ?? endpointLabel ?? "cover" }

    var isOpen: Bool {
        guard let s = stateValue?.uppercased() else { return false }
        return s == "OPEN" || s == "OPENING"
    }

    var displayState: String {
        switch stateValue?.uppercased() {
        case "OPEN":    return "Open"
        case "CLOSED":  return "Closed"
        case "OPENING": return "Opening"
        case "CLOSING": return "Closing"
        case "STOPPED": return "Stopped"
        default:        return stateValue?.capitalized ?? "Unknown"
        }
    }

    init?(device: Device, state: [String: JSONValue]) {
        self.init(device: device, state: state, coverBlock: nil)
    }

    /// Builds one context per top-level `cover` expose. Multi-endpoint covers
    /// (e.g. TS130F_dual) emit one block per shade with `state_left`/`state_right`
    /// etc., and need a separate card per endpoint.
    static func contexts(for device: Device, state: [String: JSONValue]) -> [CoverControlContext] {
        let coverBlocks = (device.definition?.exposes ?? []).filter { $0.type == "cover" }
        if coverBlocks.count <= 1 {
            return CoverControlContext(device: device, state: state).map { [$0] } ?? []
        }
        return coverBlocks.compactMap { CoverControlContext(device: device, state: state, coverBlock: $0) }
    }

    private init?(device: Device, state: [String: JSONValue], coverBlock: Expose?) {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattened
        let coverFeatures: [Expose]
        if let block = coverBlock {
            coverFeatures = (block.features ?? []).flattened
        } else {
            coverFeatures = exposes.first(where: { $0.type == "cover" })?.features ?? flat
        }

        let stateFeature = Self.find(in: coverFeatures, names: ["state"])
        let positionFeature = Self.find(in: coverFeatures, names: ["position"])
        let tiltFeature = Self.find(in: coverFeatures, names: ["tilt"])

        guard stateFeature != nil || positionFeature != nil else { return nil }

        self.stateFeature = stateFeature
        self.positionFeature = positionFeature
        self.tiltFeature = tiltFeature
        self.stateValue = state[stateFeature?.property ?? "state"]?.stringValue
        self.positionValue = positionFeature.flatMap { state[$0.property]?.numberValue }
        self.tiltValue = tiltFeature.flatMap { state[$0.property]?.numberValue }
        self.endpointLabel = coverBlock?.endpoint.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
    }

    func statePayload(_ value: String) -> JSONValue? {
        guard let f = stateFeature, f.isWritable else { return nil }
        return .object([f.property: .string(value)])
    }

    func positionPayload(_ value: Double) -> JSONValue? {
        guard let f = positionFeature, f.isWritable else { return nil }
        return .object([f.property: .int(Int(value.rounded()))])
    }

    func tiltPayload(_ value: Double) -> JSONValue? {
        guard let f = tiltFeature, f.isWritable else { return nil }
        return .object([f.property: .int(Int(value.rounded()))])
    }

    private static func find(in exposes: [Expose], names: Set<String>) -> Feature? {
        for e in exposes {
            let key = e.name ?? e.property ?? ""
            if names.contains(key) || names.contains(e.property ?? "") {
                let range: ClosedRange<Double>? = (e.valueMin != nil && e.valueMax != nil)
                    ? (e.valueMin! ... e.valueMax!) : nil
                return Feature(property: e.property ?? key, isWritable: e.isWritable, range: range)
            }
        }
        return nil
    }
}
