import SwiftUI

struct LogsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var mode: LogMode = .activity
    @State private var activityVM = LogsViewModel()
    @State private var bridgeVM = BridgeLogViewModel()
    @State private var autoOpenedEntry: LogRoute?
    let initialEntryFilter: Set<UUID>?
    private let notificationSheetStyle: Bool
    private let onDone: (() -> Void)?

    init(
        initialEntryFilter: Set<UUID>? = nil,
        notificationSheetStyle: Bool = false,
        onDone: (() -> Void)? = nil
    ) {
        self.initialEntryFilter = initialEntryFilter
        self.notificationSheetStyle = notificationSheetStyle
        self.onDone = onDone
    }

    enum LogMode: String, CaseIterable, Hashable {
        case activity = "Activity"
        case log = "Log"
    }

    var body: some View {
        NavigationStack {
            if notificationSheetStyle {
                ActivityLogContent(viewModel: activityVM)
                    .navigationTitle("Logs")
                    .navigationBarTitleDisplayMode(.inline)
                    .onAppear { applyInitialFilter(autoOpenSingle: false) }
                    .toolbar {
                        if let onDone {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done", action: onDone)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
            } else {
                modeContent
                .navigationTitle("Logs")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: searchBinding, prompt: searchPrompt)
                .onAppear { applyInitialFilter(autoOpenSingle: true) }
                .navigationDestination(item: $autoOpenedEntry) { route in
                    LogDetailView(bridgeID: route.bridgeID, entry: route.entry)
                }
                // LogDetailView's device/group hero card pushes these routes
                // when the user taps it. Without handlers on this stack the
                // links emit a runtime warning and don't navigate; the device
                // and group tabs each register the same destinations on their
                // own stacks.
                .navigationDestination(for: DeviceRoute.self) { route in
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .navigationDestination(for: GroupRoute.self) { route in
                    GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                }
                .minimizeSearchToolbarIfAvailable()
                .toolbar(.hidden, for: .tabBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $mode) {
                            ForEach(LogMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    if mode == .activity {
                        ToolbarItem(placement: .topBarTrailing) {
                            LogFilterMenu(viewModel: activityVM)
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            BridgeLevelFilterMenu(viewModel: bridgeVM)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            // Phase 1 multi-bridge: always clear across every
                            // connected session — the activity tab merges by
                            // default, and per-bridge clearing belongs in a
                            // future per-bridge logs picker.
                            for session in environment.registry.orderedSessions {
                                session.store.clearLogs()
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        let position = Binding<LogMode?>(
            get: { mode },
            set: { if let new = $0, new != mode { mode = new } }
        )
        GeometryReader { geo in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ActivityLogContent(viewModel: activityVM)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(LogMode.activity)
                    BridgeLogView(viewModel: bridgeVM)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(LogMode.log)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: position)
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { mode == .activity ? activityVM.searchText : bridgeVM.searchText },
            set: { if mode == .activity { activityVM.searchText = $0 } else { bridgeVM.searchText = $0 } }
        )
    }

    private var searchPrompt: String {
        mode == .activity ? "Search logs" : "Search messages"
    }

    private func applyInitialFilter(autoOpenSingle: Bool) {
        guard let filter = initialEntryFilter, activityVM.entryIDFilter == nil else { return }
        activityVM.entryIDFilter = filter
        guard autoOpenSingle, filter.count == 1, let id = filter.first else { return }
        // Search every connected bridge for the entry — deep-link callers
        // know the entry id but not the source bridge.
        for session in environment.registry.orderedSessions {
            if let entry = session.store.logEntries.first(where: { $0.id == id }) {
                autoOpenedEntry = LogRoute(bridgeID: session.bridgeID, entry: entry)
                return
            }
        }
    }
}

// MARK: - Activity

private struct ActivityLogContent: View {
    @Environment(AppEnvironment.self) private var environment
    let viewModel: LogsViewModel

    private var isMergedMode: Bool {
        environment.registry.sessions.values.filter(\.isConnected).count >= 2
    }

    var body: some View {
        if isMergedMode {
            mergedList
        } else {
            singleBridgeList
        }
    }

    /// Phase 1 multi-bridge: single-bridge list works only when exactly one
    /// session is connected — that session's id is the source bridge for
    /// every row.
    private var singleBridgeID: UUID? {
        environment.registry.orderedSessions.first(where: \.isConnected)?.bridgeID
    }

    @ViewBuilder
    private var singleBridgeList: some View {
        if let bridgeID = singleBridgeID,
           let session = environment.registry.session(for: bridgeID) {
            singleBridgeListBody(bridgeID: bridgeID, store: session.store)
        } else {
            List { EmptyView() }
            .listStyle(.plain)
            .overlay {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Log entries will appear as the bridge generates them in real time.")
                )
            }
        }
    }

    @ViewBuilder
    private func singleBridgeListBody(bridgeID: UUID, store: AppStore) -> some View {
        let entries = viewModel.filteredEntries(store: store)
        List {
            ForEach(entries) { entry in
                ZStack {
                    LogRowView(entry: entry, store: store, bridgeID: bridgeID)
                    NavigationLink {
                        LogDetailView(bridgeID: bridgeID, entry: entry)
                    } label: { EmptyView() }
                    .opacity(0)
                }
                .listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.logEntries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Log entries will appear as the bridge generates them in real time.")
                )
            } else if entries.isEmpty && (viewModel.hasActiveFilter || !viewModel.searchText.isEmpty) {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    @ViewBuilder
    private var mergedList: some View {
        // Run each bridge's entries through the viewModel's filter using that
        // bridge's own store (so device/group lookups in filters resolve
        // correctly), then merge by timestamp.
        let bound = mergedFilteredEntries()
        List {
            ForEach(bound) { item in
                let rowStore = environment.registry.session(for: item.bridgeID)?.store
                ZStack {
                    LogRowView(entry: item.entry, store: rowStore, bridgeID: item.bridgeID)
                    NavigationLink {
                        LogDetailView(bridgeID: item.bridgeID, entry: item.entry)
                    } label: { EmptyView() }
                    .opacity(0)
                }
                .listRowBackground(BridgeRowLeadingBar(bridgeID: item.bridgeID))
            }
        }
        .listStyle(.plain)
        .overlay {
            if environment.allLogEntries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Log entries will appear as bridges generate them in real time.")
                )
            } else if bound.isEmpty && (viewModel.hasActiveFilter || !viewModel.searchText.isEmpty) {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    private func mergedFilteredEntries() -> [BridgeBoundLogEntry] {
        let sessions = environment.registry.orderedSessions.filter { session in
            viewModel.bridgeFilter.map { $0 == session.bridgeID } ?? true
        }
        let perBridge = sessions.flatMap { session -> [BridgeBoundLogEntry] in
            viewModel.filteredEntries(store: session.store).map { entry in
                BridgeBoundLogEntry(
                    bridgeID: session.bridgeID,
                    bridgeName: session.displayName,
                    entry: entry
                )
            }
        }
        return perBridge.sorted { $0.entry.timestamp > $1.entry.timestamp }
    }
}

// MARK: - Bridge level filter

private struct BridgeLevelFilterMenu: View {
    @Bindable var viewModel: BridgeLogViewModel
    @Environment(AppEnvironment.self) private var environment

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    var body: some View {
        Menu {
            if connectedSessions.count >= 2 {
                bridgeMenu
            }
            levelMenu
            if viewModel.hasActiveFilter {
                Divider()
                Button(role: .destructive) {
                    viewModel.clearAllFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant(viewModel.hasActiveFilter ? .fill : .none)
        }
    }

    private var bridgeMenu: some View {
        Menu {
            Picker("Bridge", selection: $viewModel.bridgeFilter) {
                Label("All Bridges", systemImage: "antenna.radiowaves.left.and.right")
                    .tag(UUID?.none)
                ForEach(connectedSessions, id: \.bridgeID) { session in
                    Text(session.displayName).tag(UUID?.some(session.bridgeID))
                }
            }
            .pickerStyle(.inline)
        } label: {
            if let id = viewModel.bridgeFilter,
               let session = connectedSessions.first(where: { $0.bridgeID == id }) {
                Label("Bridge: \(session.displayName)", systemImage: "antenna.radiowaves.left.and.right")
            } else {
                Label("Bridge", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
    }

    private var levelMenu: some View {
        Menu {
            Picker("Level", selection: $viewModel.selectedLevel) {
                Label("All Levels", systemImage: "square.grid.2x2").tag(LogLevel?.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.label, systemImage: level.systemImage).tag(LogLevel?.some(level))
                }
            }
            .pickerStyle(.inline)
        } label: {
            if let level = viewModel.selectedLevel {
                Label("Level: \(level.label)", systemImage: level.systemImage)
            } else {
                Label("Level", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

#Preview {
    LogsView()
        .environment(AppEnvironment())
}
