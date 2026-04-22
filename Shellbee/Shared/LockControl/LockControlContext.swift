import Foundation

struct LockControlContext: Equatable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
    }

    let stateFeature: Feature?
    let isLocked: Bool

    init?(device: Device, state: [String: JSONValue]) {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattened
        let lockFeatures = exposes.first(where: { $0.type == "lock" })?.features ?? flat

        guard let stateFeature = Self.find(in: lockFeatures, names: ["state"]) else { return nil }
        self.stateFeature = stateFeature
        self.isLocked = state[stateFeature.property]?.stringValue?.uppercased() == "LOCK"
    }

    func togglePayload() -> JSONValue? {
        guard let f = stateFeature, f.isWritable else { return nil }
        return .object([f.property: .string(isLocked ? "UNLOCK" : "LOCK")])
    }

    private static func find(in exposes: [Expose], names: Set<String>) -> Feature? {
        for e in exposes {
            let key = e.name ?? e.property ?? ""
            if names.contains(key) || names.contains(e.property ?? "") {
                return Feature(property: e.property ?? key, isWritable: e.isWritable)
            }
        }
        return nil
    }
}
