import Foundation

struct CoverControlContext: Equatable {
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
        let exposes = device.definition?.exposes ?? []
        let flat = Self.flatten(exposes)
        let coverFeatures = exposes.first(where: { $0.type == "cover" })?.features ?? flat

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

    private static func flatten(_ exposes: [Expose]) -> [Expose] {
        exposes.flatMap { [$0] + flatten($0.features ?? []) }
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
