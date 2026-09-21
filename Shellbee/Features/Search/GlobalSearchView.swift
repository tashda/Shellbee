import SwiftUI

/// App-wide search, hosted by the tab bar's search tab on iPhone and the
/// Search sidebar item on iPad. One field searches devices, groups, bridges,
/// activity, raw log lines and the Device Library; filter bubbles narrow the
/// results to a single kind.
struct GlobalSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var query = ""
    @State private var scope: GlobalSearchScope = .all
    @State private var results = GlobalSearchResults()
    @State private var docs: [DocBrowserEntry] = []

    /// Rows per section in the mixed "All" view before "Show All" appears.
    private static let previewLimit = 4

    var body: some View {
        NavigationStack {
            resultsList
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $query, prompt: "Devices, groups, logs and more")
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .modifier(GlobalSearchDestinations())
        }
        .configuredTopScrollEdgeEffect()
        .task { docs = await DocBrowserIndex.shared.allEntries() }
        .task(id: query) {
            // Debounce keystrokes: activity and log sources can hold
            // thousands of entries.
            if !query.isEmpty {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }
            refreshResults()
        }
        .onChange(of: docs) { _, _ in refreshResults() }
    }

    @ViewBuilder
    private var resultsList: some View {
        List {
            if !query.isEmpty, !results.isEmpty {
                Section {
                    GlobalSearchScopeBar(selection: $scope, results: results)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                .listSectionSpacing(.compact)
                if scope == .all {
                    ForEach(GlobalSearchScope.categories.filter { results.count(for: $0) > 0 }) { category in
                        mixedSection(for: category)
                    }
                } else {
                    Section {
                        GlobalSearchResultRows(scope: scope, results: results)
                    } header: {
                        sectionHeader(for: scope)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { emptyState }
    }

    private func mixedSection(for category: GlobalSearchScope) -> some View {
        Section {
            GlobalSearchResultRows(scope: category, results: results, limit: Self.previewLimit)
            if results.count(for: category) > Self.previewLimit {
                Button("Show All \(results.count(for: category))") {
                    withAnimation(.snappy) { scope = category }
                }
                .font(.subheadline.weight(.semibold))
            }
        } header: {
            sectionHeader(for: category)
        }
    }

    private func sectionHeader(for category: GlobalSearchScope) -> some View {
        Label(category.title, systemImage: category.systemImage)
    }

    @ViewBuilder
    private var emptyState: some View {
        if query.isEmpty {
            ContentUnavailableView(
                "Search Shellbee",
                systemImage: "magnifyingglass",
                description: Text("Find devices, groups, bridges, activity, log lines and Device Library entries.")
            )
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        }
    }

    private func refreshResults() {
        let sessions = environment.registry.orderedSessions
        results = GlobalSearchResults(
            query: query,
            devices: environment.allDevices.filter { $0.device.type != .coordinator },
            groups: environment.allGroups,
            bridges: sessions.map {
                GlobalSearchBridge(
                    id: $0.bridgeID,
                    name: $0.displayName,
                    version: $0.store.bridgeInfo?.version,
                    isConnected: $0.isConnected
                )
            },
            activity: environment.allLogEntries,
            logs: sessions
                .flatMap { session in
                    session.store.rawLogEntries.map {
                        BridgeBoundLogEntry(bridgeID: session.bridgeID, bridgeName: session.displayName, entry: $0)
                    }
                }
                .sorted { $0.entry.timestamp > $1.entry.timestamp },
            docs: docs
        )
        if results.count(for: scope) == 0 { scope = .all }
    }
}

/// Destinations for every result type, so results push the same detail
/// views their own lists do.
private struct GlobalSearchDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: DeviceRoute.self) { route in
                DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
            }
            .navigationDestination(for: GroupRoute.self) { route in
                GroupDetailView(bridgeID: route.bridgeID, group: route.group)
            }
            .navigationDestination(for: BridgeSettingsRoute.self) { route in
                BridgeSettingsView(bridgeID: route.bridgeID)
            }
            .navigationDestination(for: LogsPaneRoute.self) { route in
                LogsPaneDestinationView(route: route)
            }
            .navigationDestination(for: DocBrowserEntry.self) { entry in
                DocBrowserDetailView(entry: entry)
            }
    }
}
