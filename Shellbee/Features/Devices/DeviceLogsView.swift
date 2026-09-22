import SwiftUI

struct DeviceLogsView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let device: Device
    @State private var searchText = ""

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var activityEvents: ActivitySubjectEvents {
        ActivitySubjectEvents(
            subjectName: device.friendlyName,
            bridgeID: bridgeID,
            store: scope.store,
            environment: environment
        )
    }

    private var items: [ActivityEventItem] {
        guard !searchText.isEmpty else { return activityEvents.items }
        let q = searchText.lowercased()
        return activityEvents.items.filter { item in
            [item.content.title, item.content.message, item.content.detail]
                .compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        List {
            ForEach(items) { item in
                ActivitySubjectEvents.Row(item: item, bridgeID: bridgeID)
            }
        }
        .listStyle(.plain)
        .overlay {
            if activityEvents.sourceEntries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Activity for \(device.friendlyName) will appear here as the bridge reports it.")
                )
            } else if items.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "tray",
                        description: Text("Only link-quality changes have been reported for \(device.friendlyName).")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search activity")
        .avoidHidingSearchToolbarContentIfAvailable()
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeviceLogsView(bridgeID: UUID(), device: .preview)
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
