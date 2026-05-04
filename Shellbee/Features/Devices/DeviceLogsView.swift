import SwiftUI

struct DeviceLogsView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let device: Device
    @State private var searchText = ""

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var allDeviceEntries: [LogEntry] {
        scope.store.logEntries.filter { $0.deviceName == device.friendlyName }
    }

    private var entries: [LogEntry] {
        guard !searchText.isEmpty else { return allDeviceEntries }
        let q = searchText.lowercased()
        return allDeviceEntries.filter { $0.message.lowercased().contains(q) }
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink {
                    LogDetailView(bridgeID: bridgeID, entry: entry, originDeviceIEEE: device.ieeeAddress)
                } label: {
                    LogRowView(entry: entry, store: scope.store, bridgeID: bridgeID)
                }
                .listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
            }
        }
        .listStyle(.plain)
        .overlay {
            if allDeviceEntries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Log entries for \(device.friendlyName) will appear here as the bridge generates them.")
                )
            } else if entries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search logs")
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeviceLogsView(bridgeID: UUID(), device: .preview)
            .environment(AppEnvironment())
    }
}
