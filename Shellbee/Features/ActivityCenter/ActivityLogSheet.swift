import SwiftUI

/// The log behind an Activity card, in a sheet that opens at half height
/// and can be pulled up to full height.
struct ActivityLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: LogRoute

    var body: some View {
        NavigationStack {
            LogDetailView(bridgeID: route.bridgeID, entry: route.entry, doneAction: { dismiss() })
                .navigationDestination(for: DeviceRoute.self) { route in
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .navigationDestination(for: GroupRoute.self) { route in
                    GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
