import SwiftUI

/// Renders the Fan device's feature sections (Behaviour, Indicators, etc.) as
/// native `List` sections. Place inside a `List` whose `.listStyle` is grouped
/// or inset-grouped. The hero / filter cards are still rendered by
/// `FanControlCard` (with `rendersSectionsInline: false`).
struct FanFeatureSections: View {
    let context: FanControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    private let filterProps: Set<String> = ["replace_filter", "filter_age", "device_age"]

    private var eligibleExtras: [Expose] {
        let claimed: Set<String> = Set(["pm25", "air_quality"]).union(filterProps)
        return context.extras.filter { e in
            guard let prop = e.property else { return false }
            return !claimed.contains(prop)
        }
    }

    private var sections: [LayoutSection] { FeatureLayout.sections(from: eligibleExtras) }

    var body: some View {
        ForEach(sections) { section in
            Section(section.title) {
                ForEach(section.items, id: \.id) { item in
                    rowFor(item)
                }
            }
        }
    }

    @ViewBuilder
    private func rowFor(_ item: LayoutItem) -> some View {
        switch item {
        case .row(let expose):
            SettingsFormRow(expose: expose, state: context.state, mode: mode, onSend: onSend)
        case .indexedGroup(let group):
            NavigationLink {
                FeatureGroupDetailView(group: group, state: context.state, mode: mode, onSend: onSend)
            } label: {
                LabeledContent(group.label) {
                    Text("\(group.members.count)")
                }
            }
        }
    }
}
