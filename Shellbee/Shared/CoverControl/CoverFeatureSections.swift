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

    private var sections: [LayoutSection] { FeatureLayout.sections(from: extras) }

    var body: some View {
        ForEach(sections) { section in
            Section(section.title) {
                ForEach(section.items, id: \.id) { item in
                    DeviceFeatureSectionRow(item: item, state: state, mode: .interactive, onSend: onSend)
                }
            }
        }
    }
}
