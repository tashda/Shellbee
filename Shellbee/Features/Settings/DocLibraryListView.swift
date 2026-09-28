import SwiftUI

/// One slice of the Device Library as rows, grouped by manufacturer (or by
/// type on a manufacturer's page), with type, manufacturer, power, feature
/// and In your network filters shown as removable chips. With a
/// `selection` it's the content column of the iPad library; otherwise rows
/// push the Documentation page.
struct DocLibraryListView: View {
    let scope: DocLibraryScope
    let allEntries: [DocBrowserEntry]
    var selection: Binding<DocBrowserEntry?>? = nil

    @Environment(AppEnvironment.self) private var environment
    @State private var filters = DocLibraryFilters()

    private var owned: [String: Int] { environment.ownedLibraryModels }

    private var scopeEntries: [DocBrowserEntry] {
        scope.entries(from: allEntries, owned: owned)
    }

    private var entries: [DocBrowserEntry] {
        scopeEntries.filter { filters.matches($0, owned: owned) }
    }

    /// The page's type, or the one chosen in the filter.
    private var features: [DocLibraryFeature] {
        switch scope {
        case .type(let type): DocLibraryFeature.features(for: type)
        case .owned, .all, .other, .vendor: DocLibraryFeature.features(for: filters.type?.deviceType)
        }
    }

    var body: some View {
        list
            .listStyle(.insetGrouped)
            .shellbeeThemedCanvas()
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Devices",
                        systemImage: FilterMenuSymbol.all,
                        description: Text(filters.isActive ? "Try removing a filter." : "Nothing in the library matches.")
                    )
                }
            }
            .navigationTitle(scope.title)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if filters.isActive {
                        ClearFiltersToolbarButton { filters = DocLibraryFilters() }
                    }
                    DocLibraryFilterMenu(filters: $filters, scope: scope,
                                         scopeEntries: scopeEntries, features: features)
                }
            }
    }

    @ViewBuilder
    private var list: some View {
        if let selection {
            List(selection: selection) {
                SwiftUI.Group {
                    rows { entry in row(entry).tag(entry) }
                }
                .shellbeeThemedRows()
            }
        } else {
            List {
                SwiftUI.Group {
                    rows { entry in
                        NavigationLink {
                            DocBrowserDetailView(entry: entry)
                        } label: {
                            row(entry)
                        }
                    }
                }
                .shellbeeThemedRows()
            }
        }
    }

    @ViewBuilder
    private func rows<Row: View>(@ViewBuilder _ content: @escaping (DocBrowserEntry) -> Row) -> some View {
        if filters.isActive {
            Section {
                activeChips
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        ForEach(sections, id: \.title) { section in
            Section(section.title) {
                ForEach(section.entries, id: \.docKey) { entry in
                    content(entry)
                }
            }
        }
    }

    private func row(_ entry: DocBrowserEntry) -> some View {
        DocEntryRow(
            entry: entry,
            showVendor: scope.groupsByType,
            ownedCount: scope == .owned ? owned[entry.ownershipKey] : nil
        )
    }

    private var sections: [(title: String, entries: [DocBrowserEntry])] {
        if scope.groupsByType {
            let byType = Dictionary(grouping: entries) { $0.deviceType }
            let order: [DocDeviceType?] = DocDeviceType.allCases.map { $0 } + [nil]
            return order.compactMap { type in
                guard let items = byType[type], !items.isEmpty else { return nil }
                return (type?.pluralTitle ?? "Other", items.sorted(by: Self.byName))
            }
        }
        let byVendor = Dictionary(grouping: entries, by: \.vendor)
        return byVendor.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { vendor in
            (vendor, byVendor[vendor, default: []].sorted(by: Self.byName))
        }
    }

    private static func byName(_ lhs: DocBrowserEntry, _ rhs: DocBrowserEntry) -> Bool {
        let l = lhs.description.isEmpty ? lhs.model : lhs.description
        let r = rhs.description.isEmpty ? rhs.model : rhs.description
        return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
    }

    // MARK: - Filter

    private var activeChips: some View {
        GlassChipRow {
            if let type = filters.type {
                // A type chip only appears on pages without their own type,
                // so its features go with it.
                RemovableFilterChip(title: type.title) {
                    filters.type = nil
                    filters.features.removeAll()
                }
            }
            if let vendor = filters.vendor {
                RemovableFilterChip(title: vendor) { filters.vendor = nil }
            }
            if let power = filters.powerTitle {
                RemovableFilterChip(title: power) { filters.power = .any }
            }
            if filters.inNetworkOnly {
                RemovableFilterChip(title: DocLibraryScope.owned.title) { filters.inNetworkOnly = false }
            }
            ForEach(features.filter(filters.features.contains)) { feature in
                RemovableFilterChip(title: feature.title) { filters.features.remove(feature) }
            }
        }
    }
}
