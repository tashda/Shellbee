import SwiftUI

/// The log behind an Activity card, in a sheet that opens at half height
/// and can be pulled up to full height.
struct ActivityLogSheet: View {
    let route: LogRoute

    var body: some View {
        NavigationStack {
            LogDetailView(bridgeID: route.bridgeID, entry: route.entry)
                .navigationDestination(for: DeviceRoute.self) { route in
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .navigationDestination(for: GroupRoute.self) { route in
                    GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                }
        }
        // Sheets are their own presentation, so the app-wide scroll-edge
        // setting has to be applied here again.
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
