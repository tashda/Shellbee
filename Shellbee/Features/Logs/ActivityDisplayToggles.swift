import SwiftUI

/// The Display section of the Activity filter menus: how the feed is
/// arranged and whether signal drift shows. Tapping a toggle keeps the menu
/// open so its checkmark is seen to change.
struct ActivityDisplayToggles: View {
    @Binding var showsSignalChanges: Bool

    @AppStorage(ActivityStackBuilder.groupsBySubjectKey) private var groupsBySubject = true
    @AppStorage(ActivityStackBuilder.pinsAttentionKey) private var pinsAttention = true

    var body: some View {
        Section("Display") {
            Toggle(isOn: $groupsBySubject) {
                Label("Group by Device", systemImage: "square.stack")
            }
            Toggle(isOn: $pinsAttention) {
                Label("Needs Attention First", systemImage: "exclamationmark.triangle")
            }
            // LQI drift is hidden by default — see LogsViewModel.
            // showLinkQualityChanges.
            Toggle(isOn: $showsSignalChanges) {
                Label("Signal Changes", systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}
