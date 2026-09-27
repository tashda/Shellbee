import SwiftUI

/// One slice of the Device Library as rows, grouped by manufacturer (or by
/// type on a manufacturer's page), with a Power Source filter. With a
/// `selection` it's the content column of the iPad library; otherwise rows
/// push the Documentation page.
struct DocLibraryListView: View {
    let scope: DocLibraryScope
    let allEntries: [DocBrowserEntry]
    var selection: Binding<DocBrowserEntry?>? = nil

    @Environment(AppEnvironment.self) private var environment
    @State private var power: PowerFilter = .any

    private var owned: [String: Int] { environment.ownedLibraryModels }

    private var entries: [DocBrowserEntry] {
        scope.entries(from: allEntries, owned: owned).filter { entry in
            switch power {
            case .any: true
            case .battery: entry.isBatteryPowered
            case .mains: !entry.isBatteryPowered
            }
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
                        description: Text(power == .any ? "Nothing in the library matches." : "Try another power source.")
                    )
                }
            }
            .navigationTitle(scope.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

    private func rows<Row: View>(@ViewBuilder _ content: @escaping (DocBrowserEntry) -> Row) -> some View {
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

    private enum PowerFilter: Hashable { case any, battery, mains }

    private var filterMenu: some View {
        Menu {
            Menu {
                Picker("Power Source", selection: $power) {
                    Label("All Power Sources", systemImage: FilterMenuSymbol.all).tag(PowerFilter.any)
                    Label("Battery", systemImage: "battery.100").tag(PowerFilter.battery)
                    Label("Mains / USB", systemImage: "powerplug.fill").tag(PowerFilter.mains)
                }
                .pickerStyle(.inline)
            } label: {
                FilterSubmenuLabel(name: "Power Source", systemImage: "bolt.circle", value: powerValue)
            }
            ClearFiltersMenuItem(isActive: power != .any) { power = .any }
        } label: {
            FilterMenuLabel(isActive: power != .any)
        }
    }

    private var powerValue: String? {
        switch power {
        case .any: nil
        case .battery: "Battery"
        case .mains: "Mains / USB"
        }
    }
}
