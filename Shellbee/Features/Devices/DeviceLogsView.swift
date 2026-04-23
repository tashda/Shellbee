import SwiftUI

struct DeviceLogsView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device
    @State private var searchText = ""

    private var entries: [LogEntry] {
        let all = environment.store.logEntries.filter { $0.deviceName == device.friendlyName }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.message.lowercased().contains(q) }
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink {
                    LogDetailView(entry: entry)
                } label: {
                    LogRowView(entry: entry)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if environment.store.logEntries.filter({ $0.deviceName == device.friendlyName }).isEmpty {
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
        DeviceLogsView(device: .preview)
            .environment(AppEnvironment())
    }
}
