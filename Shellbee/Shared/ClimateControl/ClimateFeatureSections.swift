import SwiftUI

/// Renders a thermostat's "leftover" exposes (eco mode, schedule, valve
/// position, calibration, etc.) as native iOS Settings sections beneath the
/// hero `ClimateControlCard`. Fan mode and preset are surfaced here too —
/// the card itself doesn't bind to them today but they're meaningful
/// configuration the user expects to control. Sections are grouped by
/// `FeatureLayout` (Behaviour / Indicators / Maintenance / etc.).
struct ClimateFeatureSections: View {
    let device: Device
    let context: ClimateControlContext
    let state: [String: JSONValue]
    let onSend: (JSONValue) -> Void

    private var primaryProps: Set<String> {
        var props: Set<String> = []
        if let p = context.temperatureFeature?.property { props.insert(p) }
        if let p = context.heatingSetpointFeature?.property { props.insert(p) }
        if let p = context.coolingSetpointFeature?.property { props.insert(p) }
        if let p = context.systemModeFeature?.property { props.insert(p) }
        if let p = context.runningStateFeature?.property { props.insert(p) }
        return props
    }

    private var extras: [Expose] {
        let exposes = device.definition?.exposes ?? []
        let climateBlock = exposes.first(where: { $0.type == "climate" })
        let climateInternal = climateBlock?.features?.flattenedLeaves ?? []
        var internalProps = Set(climateInternal.compactMap { $0.property })
        // Surface fan_mode + preset under Configuration even though they live
        // inside the climate composite — they're meaningful user settings.
        if let p = context.fanModeFeature?.property { internalProps.remove(p) }
        if let p = context.presetFeature?.property { internalProps.remove(p) }
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
