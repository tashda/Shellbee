import SwiftUI

/// The expanded state of the tab-bar Activity Center. A native sheet gives
/// it the direct, interactive collapse gesture users expect from a system
/// player without reimplementing a custom presentation controller.
struct ActivityCenterSheet: View {
    var body: some View {
        NavigationStack {
            LogsView(navigationTitle: "Activity")
        }
        .configuredTopScrollEdgeEffect()
    }
}
