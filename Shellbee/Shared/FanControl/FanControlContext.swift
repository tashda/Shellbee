import Foundation

struct FanControlContext: Equatable {
    struct Feature: Equatable {
        let property: String
        let isWritable: Bool
        let values: [String]?
        let range: ClosedRange<Double>?
        let step: Double?
        let unit: String?
    }

    let stateFeature: Feature?
    let fanModeFeature: Feature?
    let speedFeature: Feature?

    let isOn: Bool
    let fanMode: String?
    let speedPercent: Double?

    /// Sibling exposes (LED, child lock, PM2.5, air quality, filter age, etc.)
    /// rendered as iOS-style rows below the primary fan controls.
    let extras: [Expose]
    let state: [String: JSONValue]

    init?(device: Device, state: [String: JSONValue]) {
        let exposes = device.definition?.exposes ?? []
        let fanComposite = exposes.first(where: { $0.type == "fan" })
        let fanFeatures = fanComposite?.features ?? []
        // Pool we search for primary controls (state / mode / speed). We can
        // descend into the *fan* composite — that's the device's primary control.
        // We do NOT descend into other composites (led_effect, breeze_mode,
        // mmwave_*) because their sub-feature names collide and they need
        // bundled-payload writes that aren't supported by the leaf renderer.
        let primaryPool = fanFeatures + exposes

        let stateFeature = Self.find(in: primaryPool, names: ["state"])
        guard stateFeature != nil else { return nil }

        self.stateFeature = stateFeature
        self.fanModeFeature = Self.find(in: primaryPool, names: ["fan_mode", "mode"])
        self.speedFeature = Self.find(
            in: primaryPool,
            names: ["fan_speed_percent", "fan_speed", "speed", "percentage"]
        )

        self.isOn = state[stateFeature?.property ?? "state"]?.stringValue != "OFF"
        self.fanMode = self.fanModeFeature.flatMap { state[$0.property]?.stringValue }
        self.speedPercent = self.speedFeature.flatMap { state[$0.property]?.numberValue }
        self.state = state

        // Collect extras: all leaf exposes that are NOT primary fan controls and
        // NOT inside the fan composite (which is the device's typed control).
        let primaryProps: Set<String> = [
            stateFeature?.property,
            fanModeFeature?.property,
            speedFeature?.property
        ].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }

        let fanCompositeProps = Set(fanFeatures.flattenedLeaves.compactMap { $0.property })

        // Extras are TOP-LEVEL exposes only — we deliberately don't descend
        // into composites here. Composite features (led_effect, breeze_mode,
        // individual_led_effect, mmwave_*) reuse generic sub-feature names
        // like `color` / `level` / `duration` and require bundled-payload
        // writes; surfacing their leaves at the top level produces duplicate
        // rows that all bind to the same state key. Composites get their own
        // disclosure-sheet treatment in a follow-up.
        self.extras = exposes.filter { e in
            guard let prop = e.property, !prop.isEmpty else { return false }
            if primaryProps.contains(prop) { return false }
            if fanCompositeProps.contains(prop) { return false }
            if prop.hasPrefix("identify") { return false }
            // Belong on the device header card, not here.
            if prop == "linkquality" || prop == "battery" { return false }
            // Skip composites with sub-features — they need bundled writes.
            if let f = e.features, !f.isEmpty { return false }
            // Only render leaf types we know how to show.
            switch e.type {
            case "binary", "enum", "numeric", "text": return true
            default: return false
            }
        }
    }

    func togglePayload() -> JSONValue? {
        guard let f = stateFeature, f.isWritable else { return nil }
        return .object([f.property: .string(isOn ? "OFF" : "ON")])
    }

    func fanModePayload(_ mode: String) -> JSONValue? {
        guard let f = fanModeFeature, f.isWritable else { return nil }
        return .object([f.property: .string(mode)])
    }

    func speedPayload(_ value: Double) -> JSONValue? {
        guard let f = speedFeature, f.isWritable else { return nil }
        if let step = f.step, step.truncatingRemainder(dividingBy: 1) == 0 {
            return .object([f.property: .int(Int(value.rounded()))])
        }
        return .object([f.property: .double(value)])
    }

    private static func find(in exposes: [Expose], names: Set<String>) -> Feature? {
        for e in exposes {
            let key = e.name ?? e.property ?? ""
            if names.contains(key) || names.contains(e.property ?? "") {
                let range: ClosedRange<Double>? = (e.valueMin != nil && e.valueMax != nil)
                    ? (e.valueMin! ... e.valueMax!) : nil
                return Feature(
                    property: e.property ?? key,
                    isWritable: e.isWritable,
                    values: e.values,
                    range: range,
                    step: e.valueStep,
                    unit: e.unit
                )
            }
        }
        return nil
    }
}
