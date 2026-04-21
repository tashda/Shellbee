import SwiftUI

struct LogsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = LogsViewModel()

    var body: some View {
        NavigationStack {
            LogListContent(viewModel: viewModel)
                .navigationTitle("Logs")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.searchText, prompt: "Search logs\u{2026}")
                .searchToolbarBehavior(.minimize)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        LogFilterMenu(viewModel: viewModel, store: environment.store)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            environment.store.logEntries = []
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
        }
    }
}

private struct LogListContent: View {
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

#Preview {
    LogsView()
        .environment(AppEnvironment())
}
