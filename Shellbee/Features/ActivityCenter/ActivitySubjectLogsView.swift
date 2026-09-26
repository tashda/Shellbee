import SwiftUI

/// The subject-scoped Logs screen used by device and group detail pages.
/// Keeping this list here prevents those pages from drifting in filtering,
/// empty states, search wording or event presentation.
struct ActivitySubjectLogsView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let subjectName: String
    var showsSignalChanges = false
    @State private var searchText = ""

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var activityEvents: ActivitySubjectEvents {
        ActivitySubjectEvents(
            subjectName: subjectName,
            bridgeID: bridgeID,
            store: scope.store,
            environment: environment,
            showsSignalChanges: showsSignalChanges
        )
    }

    private var items: [ActivityEventItem] {
        guard !searchText.isEmpty else { return activityEvents.items }
        let query = searchText
        return activityEvents.items.filter { item in
            [item.content.title, item.content.message, item.content.detail]
                .compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        List {
            ForEach(items) { item in
                ActivitySubjectEvents.Row(item: item, bridgeID: bridgeID)
            }
        }
        .listStyle(.plain)
        .overlay { emptyState }
        .searchable(text: $searchText, prompt: "Search activity")
        .avoidHidingSearchToolbarContentIfAvailable()
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var emptyState: some View {
        if activityEvents.sourceEntries.isEmpty {
            ContentUnavailableView(
                "No Logs",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Activity for \(subjectName) will appear here as the bridge reports it.")
            )
        } else if items.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "tray",
                    description: Text("Only link-quality changes have been reported for \(subjectName).")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}
