import SwiftUI

/// Picks the devices Activity is filtered to. Choices are drafted locally
/// and only applied by the checkmark, so the feed and its toolbar don't
/// change underneath the sheet while the user is still picking.
struct LogDeviceFilterSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDevices: Set<String>
    let logDevices: [String]

    @State private var draft: Set<String>
    @State private var showAll = false
    @State private var searchText = ""

    init(selectedDevices: Binding<Set<String>>, logDevices: [String]) {
        _selectedDevices = selectedDevices
        self.logDevices = logDevices
        _draft = State(initialValue: selectedDevices.wrappedValue)
    }

    /// Phase 1 multi-bridge: when "Show All Devices" is on, walk every
    /// connected session to surface devices from any bridge. Resolving a
    /// `logDevices` name → Device also scans all bridges; first match wins.
    /// (Phase 2 will revisit attribution if name collisions become a real
    /// pain point.)
    private var allDevices: [Device] {
        environment.registry.orderedSessions.flatMap { $0.store.devices }
    }

    private func resolveDevice(named name: String) -> Device? {
        for session in environment.registry.orderedSessions {
            if let d = session.store.device(named: name) { return d }
        }
        return nil
    }

    private func availability(of device: Device) -> Bool {
        for session in environment.registry.orderedSessions {
            if session.store.devices.contains(where: { $0.ieeeAddress == device.ieeeAddress }) {
                return session.store.isAvailable(device.friendlyName)
            }
        }
        return false
    }

    private var candidates: [Device] {
        let base: [Device]
        if showAll {
            base = allDevices
        } else {
            base = logDevices.compactMap { resolveDevice(named: $0) }
        }
        let sorted = base.sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter {
            $0.friendlyName.lowercased().contains(q)
                || $0.definition?.vendor.lowercased().contains(q) == true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { device in
                        Button {
                            toggle(device)
                        } label: {
                            HStack {
                                DeviceFilterRow(
                                    device: device,
                                    isAvailable: availability(of: device)
                                )
                                SelectionIndicator(isSelected: draft.contains(device.friendlyName))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Devices")
                } footer: {
                    Text(selectionSummary)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search devices")
            .overlay {
                if !searchText.isEmpty && candidates.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Filter by Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Toggle(isOn: $showAll) {
                Label("Show All Devices", systemImage: "eye")
            }
            .toggleStyle(.button)
            .accessibilityHint("Includes devices without matching activity")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                draft.removeAll()
            } label: {
                Label("Clear Selection", systemImage: FilterMenuSymbol.clear)
            }
            .disabled(draft.isEmpty)
        }
        TrailingToolbarGroupSpacer()
        ToolbarItem(placement: .topBarTrailing) {
            ConfirmToolbarButton(title: "Apply") {
                selectedDevices = draft
                dismiss()
            }
        }
    }

    private var selectionSummary: String {
        if draft.isEmpty {
            return "Select one or more devices to include in Activity."
        }
        return "\(draft.count) device\(draft.count == 1 ? "" : "s") selected."
    }

    private func toggle(_ device: Device) {
        let name = device.friendlyName
        if draft.contains(name) {
            draft.remove(name)
        } else {
            draft.insert(name)
        }
    }
}

private struct DeviceFilterRow: View {
    let device: Device
    let isAvailable: Bool

    private var subtitle: String {
        if let description = device.definition?.description, !description.isEmpty {
            return description
        }
        return device.definition?.vendor ?? "Device"
    }

    var body: some View {
        IdentityRow(
            name: device.friendlyName,
            subtitle: subtitle,
            isListRow: true
        ) {
            DeviceImageView(
                device: device,
                isAvailable: isAvailable,
                size: DesignTokens.Size.summaryRowSymbolFrame
            )
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            LogDeviceFilterSheet(
                selectedDevices: .constant([]),
                logDevices: []
            )
            .environment(AppEnvironment())
        }
}
