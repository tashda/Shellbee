import SwiftUI

/// Device Library home: the models already in your network, a grid of
/// device types and every manufacturer. Searching the library happens in
/// the app-wide Search, so the page has no search field of its own.
struct DocBrowserView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var allEntries: [DocBrowserEntry] = []
    @State private var isLoading = true
    @State private var pushedScope: DocLibraryScope?

    private var ownedCount: Int {
        DocLibraryScope.owned.entries(from: allEntries, owned: environment.ownedLibraryModels).count
    }

    var body: some View {
        List {
            SwiftUI.Group {
                if !isLoading {
                    if ownedCount > 0 {
                        Section {
                            NavigationLink {
                                DocLibraryListView(scope: .owned, allEntries: allEntries)
                            } label: {
                                LabeledContent {
                                    Text("\(ownedCount)")
                                } label: {
                                    Label(DocLibraryScope.owned.title, systemImage: DocLibraryScope.owned.systemImage)
                                }
                            }
                        }
                    }

                    Section("Browse by type") {
                        DocLibraryTypeGrid(entries: allEntries) { pushedScope = $0 }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    Section("Manufacturers") {
                        ForEach(vendors, id: \.name) { vendor in
                            NavigationLink {
                                DocLibraryListView(scope: .vendor(vendor.name), allEntries: allEntries)
                            } label: {
                                LabeledContent(vendor.name) {
                                    Text("\(vendor.count)")
                                }
                            }
                        }
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .shellbeeThemedCanvas()
        .navigationTitle("Device Library")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $pushedScope) { scope in
            DocLibraryListView(scope: scope, allEntries: allEntries)
        }
        .overlay {
            if isLoading {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                    Text("Loading device library")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await loadIndex() }
    }

    private var vendors: [(name: String, count: Int)] {
        Dictionary(grouping: allEntries, by: \.vendor)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadIndex() async {
        allEntries = await DocBrowserIndex.shared.allEntries()
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        DocBrowserView()
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
