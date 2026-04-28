import SwiftUI

/// Maps a `LayoutItem` (single row or indexed group) to a native row in any
/// `…FeatureSections` view. Leaf rows render as `SettingsFormRow`; indexed
/// groups push to `FeatureGroupDetailView`.
struct DeviceFeatureSectionRow: View {
    let item: LayoutItem
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        switch item {
        case .row(let expose):
            SettingsFormRow(expose: expose, state: state, mode: mode, onSend: onSend)
        case .indexedGroup(let group):
            NavigationLink {
                FeatureGroupDetailView(group: group, state: state, mode: mode, onSend: onSend)
            } label: {
                LabeledContent(group.label) {
                    Text("\(group.members.count)")
                }
            }
        }
    }
}
