import SwiftUI

struct GroupLogsView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let group: Group
    @State private var searchText = ""

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var allGroupEntries: [LogEntry] {
        scope.store.logEntries.filter { $0.deviceName == group.friendlyName }
    }

    private var entries: [LogEntry] {
        guard !searchText.isEmpty else { return allGroupEntries }
        let q = searchText.lowercased()
        return allGroupEntries.filter { $0.message.lowercased().contains(q) }
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink {
                    LogDetailView(bridgeID: bridgeID, entry: entry)
                } label: {
                    LogRowView(entry: entry, store: scope.store, bridgeID: bridgeID)
                }
                .listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
            }
        }
        .listStyle(.plain)
        .overlay {
            if allGroupEntries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Log entries for \(group.friendlyName) will appear here as the bridge generates them.")
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
        GroupLogsView(bridgeID: UUID(), group: .previewWithMembers)
            .environment(AppEnvironment())
    }
}
