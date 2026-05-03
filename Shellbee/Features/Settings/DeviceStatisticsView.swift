import SwiftUI

struct DeviceStatisticsView: View {
    @Environment(AppEnvironment.self) private var environment
    /// Statistics are per-bridge: each Z2M instance has its own device list,
    /// so aggregating across bridges would conflate two networks. The Server
    /// page links here from a specific bridge's detail.
    let bridgeID: UUID

    private var stats: HomeStatsSnapshot {
        HomeStatsSnapshot(devices: environment.scope(for: bridgeID).store.devices)
    }

    var body: some View {
        Form {
            if !stats.deviceTypeItems.isEmpty {
                Section("Device Types") {
                    ForEach(stats.deviceTypeItems) { item in
                        LabeledContent(item.title, value: "\(item.count)")
                    }
                }
            }
            if !stats.powerSourceItems.isEmpty {
                Section("Power Sources") {
                    ForEach(stats.powerSourceItems) { item in
                        LabeledContent(item.title, value: "\(item.count)")
                    }
                }
            }
            if !stats.vendorItems.isEmpty {
                Section("Vendors") {
                    ForEach(stats.vendorItems) { item in
                        LabeledContent(item.title, value: "\(item.count)")
                    }
                }
            }
            if !stats.modelItems.isEmpty {
                Section("Models") {
                    ForEach(stats.modelItems) { item in
                        LabeledContent(item.title, value: "\(item.count)")
                    }
                }
            }
        }
        .navigationTitle("Device Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeviceStatisticsView(bridgeID: UUID()).environment(AppEnvironment())
    }
}
