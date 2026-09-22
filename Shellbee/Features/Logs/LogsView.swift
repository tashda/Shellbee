import SwiftUI

struct LogsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var workspace: LogsWorkspaceState
    @State private var autoOpenedEntry: LogRoute?
    @State private var showingClearConfirmation = false
    let initialEntryFilter: Set<UUID>?
    private let notificationSheetStyle: Bool
    /// Activity Center shows Activity as notification-style stacks instead
    /// of the plain log list used everywhere else.
    private let usesActivityFeed: Bool
    private let navigationTitle: String
    private let onDone: (() -> Void)?
    private let selection: Binding<LogsPaneRoute?>?

    init(
        initialEntryFilter: Set<UUID>? = nil,
        notificationSheetStyle: Bool = false,
        usesActivityFeed: Bool = false,
        navigationTitle: String = "Logs",
        onDone: (() -> Void)? = nil,
        selection: Binding<LogsPaneRoute?>? = nil,
        workspace: LogsWorkspaceState? = nil
    ) {
        self.initialEntryFilter = initialEntryFilter
        self.notificationSheetStyle = notificationSheetStyle
        self.usesActivityFeed = usesActivityFeed
        self.navigationTitle = navigationTitle
        self.onDone = onDone
        self.selection = selection
        _workspace = State(initialValue: workspace ?? LogsWorkspaceState())
    }

    enum LogMode: String, CaseIterable, Hashable {
        case activity = "Activity"
        case log = "Log"
    }

    var body: some View {
        // Intentionally NOT wrapped in its own NavigationStack. Each host
        // provides the stack:
        //  - Settings → Logs and BridgeSettings → Logs push LogsView onto
        //    that tab's stack via NavigationLink.
        //  - LogSheetHost (Home → Recent Events, notification taps) wraps
        //    LogsView in a NavigationStack at the sheet level.
        // A nested NavigationStack here breaks SwiftUI's value-based push
        // routing: NavigationLink(value: DeviceRoute) from inside LogDetail
        // could land on either stack, depending on iOS version, leaving the
        // user dropped back to a parent screen with nothing pushed.
        if notificationSheetStyle {
            ActivityLogContent(viewModel: workspace.activity, selection: nil)
                .navigationTitle(navigationTitle)
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
            .modifier(ActivityFeedSearch(
                isEnabled: usesActivityFeed,
                text: workspace.mode == .activity
                    ? $workspace.activity.searchText
                    : $workspace.bridge.searchText
            ))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { applyInitialFilter(autoOpenSingle: true) }
            .navigationDestination(item: $autoOpenedEntry) { route in
                LogDetailView(bridgeID: route.bridgeID, entry: route.entry)
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                if !AdaptiveLayout.isPad {
                    ToolbarItem(placement: .topBarLeading) {
                        Picker("Mode", selection: $workspace.mode) {
                            ForEach(LogMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }
                }
                if AdaptiveLayout.isPad {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        OpenInNewWindowButton(destination: .activity)
                        if activeModeHasFilter {
                            ClearFiltersToolbarButton(action: clearActiveModeFilters)
                        }
                    }
                    TrailingToolbarGroupSpacer()
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if activeModeHasFilter {
                            ClearFiltersToolbarButton(action: clearActiveModeFilters)
                        }
                        if workspace.mode == .activity {
                            LogFilterMenu(viewModel: workspace.activity)
                        } else {
                            BridgeLevelFilterMenu(viewModel: workspace.bridge)
                        }
                    }
                    TrailingToolbarGroupSpacer()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert("Clear Activity?", isPresented: $showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    // Activity is merged across connected bridges, so clear
                    // every session rather than silently leaving entries.
                    for session in environment.registry.orderedSessions {
                        session.store.clearLogs()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently clears the activity and raw log entries for every connected bridge.")
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        if usesActivityFeed {
            // No pager here: the navigation bar has to track the visible
            // list for its scroll-edge effect, and the title menu already
            // switches between Activity and Log.
            switch workspace.mode {
            case .activity:
                ActivityFeedView(viewModel: workspace.activity, selection: selection)
            case .log:
                RawLogFeedView(viewModel: workspace.bridge, selection: selection)
            }
        } else {
            pagedModeContent
        }
    }

    @ViewBuilder
    private var pagedModeContent: some View {
        let position = Binding<LogMode?>(
            get: { workspace.mode },
            set: { if let new = $0, new != workspace.mode { workspace.mode = new } }
        )
        GeometryReader { geo in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ActivityLogContent(viewModel: workspace.activity, selection: selection)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(LogMode.activity)
                    BridgeLogView(viewModel: workspace.bridge, selection: selection)
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

    private var activeModeHasFilter: Bool {
        workspace.mode == .activity ? workspace.activity.hasActiveFilter : workspace.bridge.hasActiveFilter
    }

    private func clearActiveModeFilters() {
        if workspace.mode == .activity {
            workspace.activity.clearAllFilters()
        } else {
            workspace.bridge.clearAllFilters()
        }
    }

    private func applyInitialFilter(autoOpenSingle: Bool) {
        guard let filter = initialEntryFilter, workspace.activity.entryIDFilter == nil else { return }
        workspace.activity.entryIDFilter = filter
        guard autoOpenSingle, filter.count == 1, let id = filter.first else { return }
        // Search every connected bridge for the entry — deep-link callers
        // know the entry id but not the source bridge.
        for session in environment.registry.orderedSessions {
            if let entry = session.store.logEntries.first(where: { $0.id == id }) {
                let route = LogRoute(bridgeID: session.bridgeID, entry: entry)
                if let selection {
                    selection.wrappedValue = .activity(route)
                } else {
                    autoOpenedEntry = route
                }
                return
            }
        }
    }
}

// MARK: - Activity

private struct ActivityLogContent: View {
    @Environment(AppEnvironment.self) private var environment
    let viewModel: LogsViewModel
    let selection: Binding<LogsPaneRoute?>?

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
            selectableList { EmptyView() }
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
        selectableList {
            ForEach(entries) { entry in
                activityRow(entry: entry, store: store, bridgeID: bridgeID)
                    .modifier(BridgeRowLeadingBarBackground(
                        bridgeID: bridgeID,
                        enabled: selection == nil
                    ))
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
        selectableList {
            ForEach(bound) { item in
                let rowStore = environment.registry.session(for: item.bridgeID)?.store
                activityRow(entry: item.entry, store: rowStore, bridgeID: item.bridgeID)
                    .modifier(BridgeRowLeadingBarBackground(
                        bridgeID: item.bridgeID,
                        enabled: selection == nil
                    ))
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

    @ViewBuilder
    private func activityRow(entry: LogEntry, store: AppStore?, bridgeID: UUID) -> some View {
        let route = LogRoute(bridgeID: bridgeID, entry: entry)
        let bridgeName = environment.registry.session(for: bridgeID)?.displayName ?? "Unknown"
        if selection != nil {
            NavigationLink(value: LogsPaneRoute.activity(route)) {
                LogRowView(entry: entry, store: store, bridgeID: bridgeID)
                    .accessibilityIdentifier("activity-log-\(bridgeName)")
            }
        } else {
            ZStack {
                LogRowView(entry: entry, store: store, bridgeID: bridgeID)
                    .accessibilityIdentifier("activity-log-\(bridgeName)")
                NavigationLink {
                    LogDetailView(bridgeID: bridgeID, entry: entry)
                } label: { EmptyView() }
                .opacity(0)
            }
        }
    }

    @ViewBuilder
    private func selectableList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let selection {
            List(selection: selection) {
                content()
            }
        } else {
            List {
                content()
            }
        }
    }
}

// MARK: - Activity feed search

/// Search for the Activity Center, bound to whichever mode is showing.
/// Other hosts of LogsView keep their existing filters and no search field.
private struct ActivityFeedSearch: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text, prompt: Text("Search"))
        } else {
            content
        }
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
                BridgeFilterMenu(selection: $viewModel.bridgeFilter, sessions: connectedSessions)
            }
            levelMenu
            ClearFiltersMenuItem(isActive: viewModel.hasActiveFilter) {
                viewModel.clearAllFilters()
            }
        } label: {
            FilterMenuLabel(isActive: viewModel.hasActiveFilter)
        }
    }

    private var levelMenu: some View {
        Menu {
            Picker("Level", selection: $viewModel.selectedLevel) {
                Label("All Levels", systemImage: FilterMenuSymbol.all).tag(LogLevel?.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.label, systemImage: level.systemImage).tag(LogLevel?.some(level))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(
                name: "Level",
                systemImage: "exclamationmark.triangle",
                value: viewModel.selectedLevel?.label,
                valueSystemImage: viewModel.selectedLevel?.systemImage
            )
        }
    }
}

#Preview {
    LogsView()
        .environment(AppEnvironment())
}
