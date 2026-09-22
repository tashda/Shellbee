import SwiftUI

/// Renders the Fan device's feature sections (Behaviour, Indicators, etc.) as
/// native `List` sections. Place inside a `List` whose `.listStyle` is grouped
/// or inset-grouped. The hero / filter cards are still rendered by
/// `FanControlCard` (with `rendersSectionsInline: false`).
struct FanFeatureSections: View {
    let context: FanControlContext
    let onSend: (JSONValue) -> Void

    private let filterProps: Set<String> = ["replace_filter", "filter_age", "device_age"]

    private var eligibleExtras: [Expose] {
        let claimed: Set<String> = Set(["pm25", "air_quality"]).union(filterProps)
        return context.extras.filter { e in
            guard let prop = e.property else { return false }
            return !claimed.contains(prop)
        }
    }

    var body: some View {
        FeatureSectionsList(exposes: eligibleExtras, state: context.state, onSend: onSend)
    }
}
