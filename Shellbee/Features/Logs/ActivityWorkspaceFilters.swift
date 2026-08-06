import SwiftUI

struct ActivityWorkspaceFilters: View {
    @Bindable var workspace: LogsWorkspaceState
    @Environment(AppEnvironment.self) private var environment

    private var connectedBridges: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    var body: some View {
        Section("View") {
            Picker("Mode", selection: $workspace.mode) {
                ForEach(LogsView.LogMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }

        if connectedBridges.count >= 2 {
            bridgeSection
        }

        levelSection

        if workspace.mode == .activity {
            categorySection
            namespaceSection
            deviceSection
            Section("Signal") {
                Toggle("Show Signal Changes", isOn: $workspace.activity.showLinkQualityChanges)
            }
        }

        if activeHasFilters {
            Section {
                Button("Clear Filters", role: .destructive) {
                    if workspace.mode == .activity {
                        workspace.activity.clearAllFilters()
                    } else {
                        workspace.bridge.clearAllFilters()
                    }
                }
            }
        }
    }

    private var bridgeSection: some View {
        Section("Bridge") {
            filterButton(
                title: "All Bridges",
                systemImage: "antenna.radiowaves.left.and.right",
                isSelected: activeBridgeFilter == nil
            ) { setBridgeFilter(nil) }
            ForEach(connectedBridges, id: \.bridgeID) { bridge in
                filterButton(
                    title: bridge.displayName,
                    systemImage: "antenna.radiowaves.left.and.right",
                    isSelected: activeBridgeFilter == bridge.bridgeID
                ) { setBridgeFilter(bridge.bridgeID) }
            }
        }
    }

    private var levelSection: some View {
        Section("Severity") {
            filterButton(
                title: "All Levels",
                systemImage: "square.grid.2x2",
                isSelected: activeLevel == nil
            ) { setLevel(nil) }
            ForEach(LogLevel.allCases, id: \.self) { level in
                filterButton(
                    title: level.label,
                    systemImage: level.systemImage,
                    isSelected: activeLevel == level
                ) { setLevel(level) }
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            filterButton(
                title: "All Categories",
                systemImage: "square.grid.2x2",
                isSelected: workspace.activity.selectedCategory == nil
            ) { workspace.activity.selectedCategory = nil }
            ForEach(LogCategory.allCases, id: \.self) { category in
                filterButton(
                    title: category.label,
                    systemImage: category.systemImage,
                    isSelected: workspace.activity.selectedCategory == category
                ) { workspace.activity.selectedCategory = category }
            }
        }
    }

    @ViewBuilder
    private var namespaceSection: some View {
        let namespaces = availableNamespaces
        if !namespaces.isEmpty {
            Section("Namespace") {
                filterButton(
                    title: "All Namespaces",
                    systemImage: "text.magnifyingglass",
                    isSelected: workspace.activity.selectedNamespace == nil
                ) { workspace.activity.selectedNamespace = nil }
                ForEach(namespaces, id: \.self) { namespace in
                    filterButton(
                        title: namespace,
                        systemImage: "text.magnifyingglass",
                        isSelected: workspace.activity.selectedNamespace == namespace
                    ) { workspace.activity.selectedNamespace = namespace }
                }
            }
        }
    }

    @ViewBuilder
    private var deviceSection: some View {
        let devices = availableDevices
        if !devices.isEmpty {
            Section("Device") {
                filterButton(
                    title: "All Devices",
                    systemImage: "cpu",
                    isSelected: workspace.activity.selectedDevices.isEmpty
                ) { workspace.activity.selectedDevices.removeAll() }
                ForEach(devices, id: \.self) { device in
                    filterButton(
                        title: device,
                        systemImage: "cpu",
                        isSelected: workspace.activity.selectedDevices.contains(device)
                    ) {
                        if workspace.activity.selectedDevices.contains(device) {
                            workspace.activity.selectedDevices.remove(device)
                        } else {
                            workspace.activity.selectedDevices.insert(device)
                        }
                    }
                }
            }
        }
    }

    private var activeBridgeFilter: UUID? {
        workspace.mode == .activity ? workspace.activity.bridgeFilter : workspace.bridge.bridgeFilter
    }

    private var activeLevel: LogLevel? {
        workspace.mode == .activity ? workspace.activity.selectedLevel : workspace.bridge.selectedLevel
    }

    private var activeHasFilters: Bool {
        workspace.mode == .activity ? workspace.activity.hasActiveFilter : workspace.bridge.hasActiveFilter
    }

    private var filteredSessions: [BridgeSession] {
        connectedBridges.filter { session in
            workspace.activity.bridgeFilter.map { $0 == session.bridgeID } ?? true
        }
    }

    private var availableNamespaces: [String] {
        Set(filteredSessions.flatMap { $0.store.logEntries.compactMap(\.namespace) }).sorted()
    }

    private var availableDevices: [String] {
        Set(filteredSessions.flatMap { $0.store.logEntries.compactMap(\.deviceName) }).sorted()
    }

    private func setBridgeFilter(_ bridgeID: UUID?) {
        if workspace.mode == .activity {
            workspace.activity.bridgeFilter = bridgeID
        } else {
            workspace.bridge.bridgeFilter = bridgeID
        }
    }

    private func setLevel(_ level: LogLevel?) {
        if workspace.mode == .activity {
            workspace.activity.selectedLevel = level
        } else {
            workspace.bridge.selectedLevel = level
        }
    }

    private func filterButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Active filter" : "")
    }
}
