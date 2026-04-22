import SwiftUI

struct LogsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var mode: LogMode = .activity
    @State private var activityVM = LogsViewModel()
    @State private var bridgeVM = BridgeLogViewModel()

    enum LogMode: String, CaseIterable, Hashable {
        case activity = "Activity"
        case log = "Log"
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $mode) {
                ActivityLogContent(viewModel: activityVM)
                    .tag(LogMode.activity)
                BridgeLogView(viewModel: bridgeVM)
                    .tag(LogMode.log)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: searchBinding, prompt: searchPrompt)
            .searchToolbarBehavior(.minimize)
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
                        LogFilterMenu(viewModel: activityVM, store: environment.store)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        BridgeLevelFilterMenu(viewModel: bridgeVM)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        environment.store.clearLogs()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
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
}

// MARK: - Activity

private struct ActivityLogContent: View {
    @Environment(AppEnvironment.self) private var environment
    let viewModel: LogsViewModel

    var body: some View {
        let entries = viewModel.filteredEntries(store: environment.store)
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
