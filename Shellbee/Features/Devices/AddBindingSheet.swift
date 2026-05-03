import SwiftUI

struct AddBindingSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let device: Device
    let onBind: (String, [String]) -> Void

    @State private var selectedClusters: Set<String>
    @State private var searchText = ""

    init(device: Device, onBind: @escaping (String, [String]) -> Void) {
        self.device = device
        self.onBind = onBind
        _selectedClusters = State(initialValue: Set(Self.bindableClusters(from: device)))
    }

    private static let skipClusters: Set<String> = ["genOta", "greenPower", "genPollCtrl", "touchlink"]

    static func bindableClusters(from device: Device) -> [String] {
        var clusters: Set<String> = []
        for (_, v) in device.endpoints ?? [:] {
            if let arr = v.object?["clusters"]?.object?["output"]?.array {
                clusters.formUnion(arr.compactMap(\.stringValue).filter { !skipClusters.contains($0) })
            }
        }
        return clusters.sorted()
    }

    private static func inputClusters(from device: Device) -> Set<String> {
        var clusters: Set<String> = []
        for (_, v) in device.endpoints ?? [:] {
            if let arr = v.object?["clusters"]?.object?["input"]?.array {
                clusters.formUnion(arr.compactMap(\.stringValue))
            }
        }
        return clusters
    }

    private var availableClusters: [String] { Self.bindableClusters(from: device) }

    /// Multi-bridge: bind candidates must come from the SAME bridge as
    /// `device` — z2m can't bind across networks. Resolves the source bridge
    /// from the registry, falling back to the focused store.
    private var sourceStore: AppStore {
        environment.bridge(forDevice: device.friendlyName)?.store ?? environment.store
    }

    private var bindableDevices: [Device] {
        let myOut = Set(availableClusters)
        let store = sourceStore
        return store.devices
            .filter { d in
                guard d.ieeeAddress != device.ieeeAddress, d.type != .coordinator else { return false }
                guard store.isAvailable(d.friendlyName) else { return false }
                guard !myOut.isEmpty, !(d.endpoints ?? [:]).isEmpty else { return true }
                return !myOut.intersection(Self.inputClusters(from: d)).isEmpty
            }
            .sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
    }

    private var filteredDevices: [Device] {
        guard !searchText.isEmpty else { return bindableDevices }
        let q = searchText.lowercased()
        return bindableDevices.filter {
            $0.friendlyName.lowercased().contains(q)
                || $0.definition?.vendor.lowercased().contains(q) == true
                || $0.definition?.model.lowercased().contains(q) == true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !availableClusters.isEmpty {
                    Section("Clusters to Bind") {
                        ForEach(availableClusters, id: \.self) { cluster in
                            Toggle(isOn: Binding(
                                get: { selectedClusters.contains(cluster) },
                                set: { if $0 { selectedClusters.insert(cluster) } else { selectedClusters.remove(cluster) } }
                            )) {
                                Text(cluster).font(.system(.subheadline, design: .monospaced))
                            }
                        }
                    }
                }

                Section("Infrastructure") {
                    Button { send("coordinator") } label: { CoordinatorRow() }
                }

                if !filteredDevices.isEmpty || !searchText.isEmpty {
                    Section("Devices") {
                        ForEach(filteredDevices) { target in
                            Button { send(target.friendlyName) } label: {
                                BindTargetRow(device: target)
                            }
                        }
                    }
                }

                if !environment.store.groups.isEmpty {
                    Section("Groups") {
                        ForEach(environment.store.groups) { group in
                            Button { send(group.friendlyName) } label: {
                                Label(group.friendlyName, systemImage: "rectangle.3.group.fill")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search")
            .overlay {
                if !searchText.isEmpty && filteredDevices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Add Binding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func send(_ target: String) {
        onBind(target, Array(selectedClusters).sorted())
        dismiss()
    }
}

private typealias BindTargetRow = DevicePickerRow

private struct CoordinatorRow: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground)
                    .fill(Color.purple.opacity(DesignTokens.Opacity.chipFill))
                    .frame(width: DesignTokens.Size.summaryRowSymbolFrame,
                           height: DesignTokens.Size.summaryRowSymbolFrame)
                Image(systemName: "network")
                    .font(.system(size: DesignTokens.Size.chipSymbol + 4, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("ZIGBEE2MQTT")
                    .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(DesignTokens.Opacity.secondaryText))
                Text("Coordinator")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

#Preview {
    AddBindingSheet(device: .preview) { _, _ in }
        .environment(AppEnvironment())
}
