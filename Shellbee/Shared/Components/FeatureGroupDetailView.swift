import SwiftUI

/// Pushed when a `LayoutItem.indexedGroup` row is tapped in any
/// `…FeatureSections` view. Renders the group's members as native rows so the
/// surface looks identical to the parent settings list.
struct FeatureGroupDetailView: View {
    let group: IndexedGroup
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(group.members, id: \.property) { e in
                    SettingsFormRow(expose: e, state: state, mode: mode, onSend: onSend)
                }
            }
        }
        .navigationTitle(group.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}
