import SwiftUI

/// Renders a switch's "leftover" exposes (power-on behaviour, child lock,
/// indicator config, timers, etc.) as native iOS Settings sections beneath
/// the hero `SwitchControlCard`. Sections are grouped by `FeatureLayout` so
/// behaviour / indicators / maintenance / etc. each get their own header,
/// matching the fan pattern.
struct SwitchFeatureSections: View {
    let device: Device
    let context: SwitchControlContext
    let state: [String: JSONValue]
    let onSend: (JSONValue) -> Void

    private var primaryProps: Set<String> {
        var props: Set<String> = []
        if let p = context.stateFeature?.property { props.insert(p) }
        if let p = context.powerFeature?.property { props.insert(p) }
        if let p = context.energyFeature?.property { props.insert(p) }
        if let p = context.voltageFeature?.property { props.insert(p) }
        if let p = context.currentFeature?.property { props.insert(p) }
        return props
    }

    private var extras: [Expose] {
        let exposes = device.definition?.exposes ?? []
        let switchInternal = exposes.first(where: { $0.type == "switch" })?.features?.flattenedLeaves ?? []
        let internalProps = Set(switchInternal.compactMap { $0.property })
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
