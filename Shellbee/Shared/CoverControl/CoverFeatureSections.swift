import SwiftUI

/// Renders a cover's "leftover" exposes (calibration, motor speed, child
/// lock, etc.) as native iOS Settings sections beneath the hero
/// `CoverControlCard`. Sections are grouped by `FeatureLayout` so behaviour /
/// indicators / maintenance each get their own header.
struct CoverFeatureSections: View {
    let device: Device
    let context: CoverControlContext
    let state: [String: JSONValue]
    let onSend: (JSONValue) -> Void

    private var primaryProps: Set<String> {
        var props: Set<String> = []
        if let p = context.stateFeature?.property { props.insert(p) }
        if let p = context.positionFeature?.property { props.insert(p) }
        if let p = context.tiltFeature?.property { props.insert(p) }
        return props
    }

    private var extras: [Expose] {
        let exposes = device.definition?.exposes ?? []
        let coverInternal = exposes.first(where: { $0.type == "cover" })?.features?.flattenedLeaves ?? []
        let internalProps = Set(coverInternal.compactMap { $0.property })
        return DeviceExtras.eligibleLeaves(
            from: exposes,
            primaryProps: primaryProps,
            extraExcludedProps: internalProps
        )
    }

    /// Tilt is a control but rarely changed, so it sits with the settings
    /// as a slider row instead of a second capsule on the card. One per
    /// cover block, so dual covers keep both.
    static func tiltExposes(for device: Device) -> [Expose] {
        (device.definition?.exposes ?? [])
            .filter { $0.type == "cover" }
            .flatMap { ($0.features ?? []).flattenedLeaves }
            .filter { $0.name == "tilt" && $0.property != nil }
    }

    var body: some View {
        FeatureSectionsList(exposes: Self.tiltExposes(for: device) + extras, state: state, onSend: onSend)
    }
}
