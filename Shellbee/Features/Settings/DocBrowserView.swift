import SwiftUI

// MARK: - Filter state

struct DocBrowserFilters: Equatable {
    var deviceType: DocDeviceType? = nil
    var batteryOnly: Bool = false
    var mainsOnly: Bool = false
    var vendor: String? = nil

    var isActive: Bool { deviceType != nil || batteryOnly || mainsOnly || vendor != nil }
}

// MARK: - Private data model

private struct SectionData {
    let vendor: String
    let entries: [DocBrowserEntry]
}

// MARK: - Main view

struct DocBrowserView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var allEntries: [DocBrowserEntry] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var filters = DocBrowserFilters()
    @State private var showManufacturerSheet = false

    var body: some View {
        List {
            if searchText.isEmpty {
                ForEach(sectionData, id: \.vendor) { section in
                    Section {
                        ForEach(section.entries, id: \.docKey) { entry in
                            NavigationLink(destination: DocBrowserDetailView(entry: entry)) {
                                DocEntryRow(entry: entry)
                            }
                        }
                    } header: {
                        Text(section.vendor)
                    }
                }
            } else {
                ForEach(flatSearchResults) { entry in
                    NavigationLink(destination: DocBrowserDetailView(entry: entry)) {
                        DocEntryRow(entry: entry, showVendor: true)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Device Library")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search model, vendor, description")
        .searchToolbarBehavior(.minimize)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                DocBrowserFilterMenu(
                    filters: $filters,
                    showManufacturerSheet: $showManufacturerSheet
                )
            }
        }
        .sheet(isPresented: $showManufacturerSheet) {
            ManufacturerFilterSheet(selected: $filters.vendor, allVendors: allVendors)
        }
        .overlay {
            if isLoading {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                    Text("Loading device library")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if !searchText.isEmpty && flatSearchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if sectionData.isEmpty {
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try removing some filters.")
                )
            }
        }
        .task { await loadIndex() }
    }

    // MARK: Data

    private var filtered: [DocBrowserEntry] {
        allEntries.filter { entry in
            if let t = filters.deviceType, entry.deviceType != t { return false }
            if filters.batteryOnly && !entry.isBatteryPowered { return false }
            if filters.mainsOnly   &&  entry.isBatteryPowered { return false }
            if let v = filters.vendor, entry.vendor != v { return false }
            return true
        }
    }

    private var flatSearchResults: [DocBrowserEntry] {
        // Tokenize on whitespace and require every token to appear (as a
        // substring) somewhere in the combined vendor/model/description.
        // This makes "Shelly Mini", "Shell Mini", "mini shelly", etc. all
        // match "Shelly 1 Mini Gen 4". Single-word substring search is
        // preserved for queries without spaces.
        let tokens = searchText
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !tokens.isEmpty else { return [] }
        return filtered.filter { entry in
            let haystack = "\(entry.vendor) \(entry.model) \(entry.description)".lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }
        .sorted { ($0.vendor, $0.model) < ($1.vendor, $1.model) }
    }

    private var sectionData: [SectionData] {
        let byVendor = Dictionary(grouping: filtered, by: \.vendor)
        let typeOrder: (DocDeviceType?) -> Int = { type in
            guard let t = type else { return DocDeviceType.allCases.count }
            return DocDeviceType.allCases.firstIndex(of: t) ?? DocDeviceType.allCases.count
        }
        return byVendor.keys.sorted().map { vendor in
            let sorted = byVendor[vendor]!.sorted {
                let to = typeOrder($0.deviceType)
                let tn = typeOrder($1.deviceType)
                return to != tn ? to < tn : $0.model < $1.model
            }
            return SectionData(vendor: vendor, entries: sorted)
        }
    }

    private var allVendors: [String] {
        Array(Set(allEntries.map(\.vendor))).sorted()
    }

    private func loadIndex() async {
        allEntries = await DocBrowserIndex.shared.allEntries()
        isLoading = false
    }
}

// MARK: - Entry row

private struct DocEntryRow: View {
    let entry: DocBrowserEntry
    var showVendor: Bool = false

    @State private var bundledImageData: Data?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            deviceImage
            VStack(alignment: .leading, spacing: 0) {
                if showVendor {
                    Text(entry.vendor.uppercased())
                        .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(DesignTokens.Opacity.secondaryText))
                        .lineLimit(1)
                }
                Text(entry.model)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .task(id: entry.docKey) {
            bundledImageData = nil
            if let key = entry.imageKey {
                bundledImageData = await BundledImageStore.shared.imageData(for: key)
            }
        }
    }

    @ViewBuilder
    private var deviceImage: some View {
        let size = DesignTokens.Size.summaryRowSymbolFrame
        if let data = bundledImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .transition(.opacity)
        } else {
            PersistentAsyncImage(url: entry.networkImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } placeholder: {
                Image(systemName: entry.deviceType?.systemImage ?? "cpu")
                    .font(.system(size: size * DesignTokens.Typography.iconRatioHalf, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - DocBrowserEntry network image URL (fallback when bundle unavailable)

fileprivate extension DocBrowserEntry {
    var networkImageURL: URL? {
        let stem = imageKey ?? model
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return URL(string: "https://www.zigbee2mqtt.io/images/devices/\(stem).png")
    }
}

// MARK: - Filter menu

private struct DocBrowserFilterMenu: View {
    @Binding var filters: DocBrowserFilters
    @Binding var showManufacturerSheet: Bool

    var body: some View {
        Menu {
            Menu {
                Picker("Device Type", selection: $filters.deviceType) {
                    Label("All Types", systemImage: "square.grid.2x2")
                        .tag(DocDeviceType?.none)
                    ForEach(DocDeviceType.allCases) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .tag(DocDeviceType?.some(type))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                if let type = filters.deviceType {
                    Label("Type: \(type.rawValue)", systemImage: type.systemImage)
                } else {
                    Label("Type", systemImage: "tag")
                }
            }

            Menu {
                Picker("Power Source", selection: powerBinding) {
                    Label("Any Power Source", systemImage: "bolt.circle").tag(PowerFilter.any)
                    Label("Battery", systemImage: "battery.100").tag(PowerFilter.battery)
                    Label("Mains / USB", systemImage: "powerplug.fill").tag(PowerFilter.mains)
                }
                .pickerStyle(.inline)
            } label: {
                switch currentPower {
                case .battery: Label("Power: Battery", systemImage: "battery.100")
                case .mains:   Label("Power: Mains / USB", systemImage: "powerplug.fill")
                case .any:     Label("Power Source", systemImage: "bolt.circle")
                }
            }

            Button {
                showManufacturerSheet = true
            } label: {
                if let vendor = filters.vendor {
                    Label(vendor, systemImage: "building.2.fill")
                } else {
                    Label("Manufacturer", systemImage: "building.2")
                }
            }

            if filters.isActive {
                Divider()
                Button(role: .destructive) {
                    filters = DocBrowserFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant(filters.isActive ? .fill : .none)
        }
    }

    private enum PowerFilter: Hashable { case any, battery, mains }

    private var currentPower: PowerFilter {
        if filters.batteryOnly { return .battery }
        if filters.mainsOnly   { return .mains }
        return .any
    }

    private var powerBinding: Binding<PowerFilter> {
        Binding(
            get: { currentPower },
            set: {
                filters.batteryOnly = ($0 == .battery)
                filters.mainsOnly   = ($0 == .mains)
            }
        )
    }
}

// MARK: - Manufacturer filter sheet

private struct ManufacturerFilterSheet: View {
    @Binding var selected: String?
    let allVendors: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filteredVendors: [String] {
        search.isEmpty ? allVendors : allVendors.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let current = selected {
                    Button(role: .destructive) {
                        selected = nil
                        dismiss()
                    } label: {
                        Label("Clear: \(current)", systemImage: "xmark.circle.fill")
                    }
                }
                ForEach(filteredVendors, id: \.self) { vendor in
                    vendorRow(vendor)
                }
            }
            .searchable(text: $search, prompt: "Search manufacturers")
            .searchToolbarBehavior(.minimize)
            .navigationTitle("Manufacturer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func vendorRow(_ vendor: String) -> some View {
        HStack {
            Text(vendor)
                .foregroundStyle(.primary)
            Spacer()
            if selected == vendor {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selected = vendor
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        DocBrowserView()
            .environment(AppEnvironment())
    }
}
