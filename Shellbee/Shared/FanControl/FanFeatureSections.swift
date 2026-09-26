import SwiftUI

/// Renders the Fan device's feature sections (Behaviour, Indicators, etc.) as
/// native `List` sections. Place inside a `List` whose `.listStyle` is grouped
/// or inset-grouped. The hero / filter cards are still rendered by
/// `FanControlCard` (with `rendersSectionsInline: false`).
struct FanFeatureSections: View {
    let context: FanControlContext
    let onSend: (JSONValue) -> Void

    /// Air readings and filter health have their own sections.
    private var eligibleExtras: [Expose] {
        context.extras.filter { e in
            guard let prop = e.property else { return false }
            return !FanAirReadings.claimedProperties.contains(prop)
        }
    }

    var body: some View {
        FeatureSectionsList(exposes: eligibleExtras, state: context.state, onSend: onSend)
    }
}
