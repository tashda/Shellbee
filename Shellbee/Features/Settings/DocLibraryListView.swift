import SwiftUI

/// One slice of the Device Library as rows, grouped by manufacturer (or by
/// type on a manufacturer's page), with power, feature and In your
/// network filters shown as removable chips. With a
/// `selection` it's the content column of the iPad library; otherwise rows
/// push the Documentation page.
struct DocLibraryListView: View {
    let scope: DocLibraryScope
    let allEntries: [DocBrowserEntry]
    var selection: Binding<DocBrowserEntry?>? = nil

    @Environment(AppEnvironment.self) private var environment
    @State private var filters = DocLibraryFilters()

    private var owned: [String: Int] { environment.ownedLibraryModels }

    private var entries: [DocBrowserEntry] {
        scope.entries(from: allEntries, owned: owned).filter { filters.matches($0, owned: owned) }
    }

    private var features: [DocLibraryFeature] {
        switch scope {
        case .type(let type): DocLibraryFeature.features(for: type)
        case .owned, .all, .other, .vendor: []
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
                    filterMenu
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.xs) {
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
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }

    private var filterMenu: some View {
        Menu {
            if !features.isEmpty {
                Section("Features") {
                    ForEach(features) { feature in
                        Toggle(isOn: featureBinding(feature)) {
                            Label(feature.title, systemImage: feature.systemImage)
                        }
                    }
                }
            }
            Menu {
                Picker("Power Source", selection: $filters.power) {
                    Label("All Power Sources", systemImage: FilterMenuSymbol.all).tag(DocLibraryFilters.Power.any)
                    Label("Battery", systemImage: "battery.100").tag(DocLibraryFilters.Power.battery)
                    Label("Mains / USB", systemImage: "powerplug.fill").tag(DocLibraryFilters.Power.mains)
                }
                .pickerStyle(.inline)
            } label: {
                FilterSubmenuLabel(name: "Power Source", systemImage: "bolt.circle", value: filters.powerTitle)
            }
            if scope != .owned {
                Toggle(isOn: $filters.inNetworkOnly) {
                    Label(DocLibraryScope.owned.title, systemImage: DocLibraryScope.owned.systemImage)
                }
            }
            ClearFiltersMenuItem(isActive: filters.isActive) { filters = DocLibraryFilters() }
        } label: {
            FilterMenuLabel(isActive: filters.isActive)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func featureBinding(_ feature: DocLibraryFeature) -> Binding<Bool> {
        Binding(
            get: { filters.features.contains(feature) },
            set: { isOn in
                if isOn { filters.features.insert(feature) } else { filters.features.remove(feature) }
            }
        )
    }
}
