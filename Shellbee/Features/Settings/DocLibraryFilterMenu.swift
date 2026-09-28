import SwiftUI

/// The Device Library's filter menu. Type and Manufacturer appear wherever
/// the page isn't already one of them (IKEA can filter by type, Lights by
/// manufacturer), with counts from the page's own entries. Features follow
/// the page's type or the chosen one.
struct DocLibraryFilterMenu: View {
    @Binding var filters: DocLibraryFilters
    let scope: DocLibraryScope
    /// The page's entries before filtering, for the counts.
    let scopeEntries: [DocBrowserEntry]
    let features: [DocLibraryFeature]

    private var showsType: Bool {
        switch scope {
        case .type, .other: false
        case .owned, .all, .vendor: true
        }
    }

    private var showsVendor: Bool {
        if case .vendor = scope { return false }
        return true
    }

    var body: some View {
        Menu {
            if showsType { typeMenu }
            if showsVendor { vendorMenu }
            if !features.isEmpty {
                Section("Features") {
                    ForEach(features) { feature in
                        Toggle(isOn: featureBinding(feature)) {
                            Label(feature.title, systemImage: feature.systemImage)
                        }
                    }
                }
            }
            powerMenu
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

    private var typeMenu: some View {
        let counts = Dictionary(grouping: scopeEntries, by: \.deviceType).mapValues(\.count)
        let types = DocLibraryTypeFilter.all.filter { counts[$0.deviceType, default: 0] > 0 || $0 == filters.type }
        return Menu {
            Picker("Type", selection: typeBinding) {
                Label("All Types", systemImage: FilterMenuSymbol.all).tag(DocLibraryTypeFilter?.none)
                ForEach(types) { type in
                    Label("\(type.title) (\(counts[type.deviceType, default: 0]))", systemImage: type.systemImage)
                        .tag(DocLibraryTypeFilter?.some(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(name: "Type", systemImage: "tag", value: filters.type?.title,
                               valueSystemImage: filters.type?.systemImage)
        }
    }

    private var vendorMenu: some View {
        let counts = Dictionary(grouping: scopeEntries, by: \.vendor).mapValues(\.count)
        let vendors = counts.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return Menu {
            Picker("Manufacturer", selection: $filters.vendor) {
                Label("All Manufacturers", systemImage: FilterMenuSymbol.all).tag(String?.none)
                ForEach(vendors, id: \.self) { vendor in
                    Text("\(vendor) (\(counts[vendor, default: 0]))").tag(String?.some(vendor))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(name: "Manufacturer", systemImage: "building.2", value: filters.vendor)
        }
    }

    private var powerMenu: some View {
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
    }

    /// Changing type drops features that belonged to the old one.
    private var typeBinding: Binding<DocLibraryTypeFilter?> {
        Binding(
            get: { filters.type },
            set: { type in
                filters.type = type
                let allowed = Set(DocLibraryFeature.features(for: type?.deviceType))
                filters.features = filters.features.intersection(allowed)
            }
        )
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
