import SwiftUI

struct LogsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var mode: LogMode = .activity
    @State private var activityVM = LogsViewModel()
    @State private var bridgeVM = BridgeLogViewModel()
    @State private var autoOpenedEntry: LogEntry?
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
                .navigationDestination(item: $autoOpenedEntry) { entry in
                    LogDetailView(entry: entry)
                }
                .minimizeSearchToolbarIfAvailable()
                .toolbar(.hidden, for: .tabBar)
                .toolbar {
                    BridgeSwitcherToolbarItem()
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $mode) {
                            ForEach(LogMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    if mode == .activity {
                        ToolbarItem(placement: .topBarTrailing) {
                            LogFilterMenu(viewModel: activityVM, store: environment.store)
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            BridgeLevelFilterMenu(viewModel: bridgeVM)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            // In merged-multi-bridge mode, clear every bridge's
                            // logs so the visible list is fully reset. Single-
                            // bridge mode keeps the legacy single-store behavior.
                            if environment.registry.sessions.count >= 2 {
                                for session in environment.registry.orderedSessions {
                                    session.store.clearLogs()
                                }
                            } else {
                                environment.store.clearLogs()
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
        guard autoOpenSingle, filter.count == 1, let id = filter.first,
              let entry = environment.store.logEntries.first(where: { $0.id == id }) else { return }
        autoOpenedEntry = entry
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

    @ViewBuilder
    private var singleBridgeList: some View {
        let entries = viewModel.filteredEntries(store: environment.store)
        List {
            ForEach(entries) { entry in
                ZStack {
                    LogRowView(entry: entry)
                    NavigationLink {
                        LogDetailView(entry: entry)
                    } label: { EmptyView() }
                    .opacity(0)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if environment.store.logEntries.isEmpty {
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
                ZStack {
                    HStack(alignment: .center, spacing: DesignTokens.Spacing.xs) {
                        LogRowView(entry: item.entry)
                        BridgeBadge(
                            bridgeName: item.bridgeName,
                            isFocused: environment.registry.primaryBridgeID == item.bridgeID
                        )
                    }
                    NavigationLink {
                        LogDetailView(entry: item.entry)
                    } label: { EmptyView() }
                    .opacity(0)
                    .simultaneousGesture(TapGesture().onEnded {
                        // Switch focus before pushing detail so the destination
                        // resolves device/group references against the right
                        // bridge's store.
                        if environment.registry.primaryBridgeID != item.bridgeID {
                            environment.registry.setPrimary(item.bridgeID)
                        }
                    })
                }
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
        let perBridge = environment.registry.orderedSessions.flatMap { session -> [BridgeBoundLogEntry] in
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

    var body: some View {
        Menu {
            Picker("Level", selection: $viewModel.selectedLevel) {
                Label("All Levels", systemImage: "square.grid.2x2").tag(LogLevel?.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.label, systemImage: level.systemImage).tag(LogLevel?.some(level))
                }
            }
            .pickerStyle(.inline)
            if viewModel.hasActiveFilter {
                Divider()
                Button(role: .destructive) {
                    viewModel.selectedLevel = nil
                } label: {
                    Label("Clear Filter", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant(viewModel.hasActiveFilter ? .fill : .none)
        }
    }
}

#Preview {
    LogsView()
        .environment(AppEnvironment())
}
