import SwiftUI

struct DeviceWorkspaceFilters: View {
    @Bindable var viewModel: DeviceListViewModel
    @Environment(AppEnvironment.self) private var environment

    private var connectedBridges: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    private var filterStores: [AppStore] {
        connectedBridges
            .filter { bridge in
                viewModel.bridgeFilter.map { $0 == bridge.bridgeID } ?? true
            }
            .map(\.store)
    }

    private var availableVendors: [String] {
        Set(filterStores.flatMap { store in
            store.devices.compactMap { $0.definition?.vendor }
        }).sorted()
    }

    var body: some View {
        if viewModel.hasActiveFilter {
            Section {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Label("Clear filter", systemImage: "xmark.circle")
                }
            }
        }

        if connectedBridges.count >= 2 {
            Section("Bridge") {
                filterButton(
                    title: "All Bridges",
                    systemImage: "antenna.radiowaves.left.and.right",
                    isSelected: viewModel.bridgeFilter == nil
                ) { viewModel.bridgeFilter = nil }
                ForEach(connectedBridges, id: \.bridgeID) { bridge in
                    if viewModel.bridgeFilter == bridge.bridgeID || hasDevices(on: bridge) {
                        filterButton(
                            title: bridge.displayName,
                            systemImage: "antenna.radiowaves.left.and.right",
                            isSelected: viewModel.bridgeFilter == bridge.bridgeID
                        ) { viewModel.bridgeFilter = bridge.bridgeID }
                    }
                }
            }
        }

        Section("Availability & Updates") {
            ForEach(DeviceStatusFilter.allCases, id: \.self) { status in
                if status == .all || viewModel.statusFilter == status || hasDevices(for: status) {
                    filterButton(
                        title: status.rawValue,
                        systemImage: status.systemImage,
                        isSelected: viewModel.statusFilter == status
                    ) { viewModel.statusFilter = status }
                }
            }
        }

        Section("Device Type") {
            filterButton(
                title: "All Types",
                systemImage: "square.grid.2x2",
                isSelected: viewModel.categoryFilter == nil
            ) { viewModel.categoryFilter = nil }
            ForEach(Device.Category.allCases, id: \.self) { category in
                if viewModel.categoryFilter == category || hasDevices(for: category) {
                    filterButton(
                        title: category.label,
                        systemImage: category.systemImage,
                        isSelected: viewModel.categoryFilter == category
                    ) { viewModel.categoryFilter = category }
                }
            }
        }

        if !availableVendors.isEmpty {
            Section("Manufacturer") {
                filterButton(
                    title: "All Manufacturers",
                    systemImage: "building.2",
                    isSelected: viewModel.vendorFilter == nil
                ) { viewModel.vendorFilter = nil }
                ForEach(availableVendors, id: \.self) { vendor in
                    if viewModel.vendorFilter == vendor || hasDevices(for: vendor) {
                        filterButton(
                            title: vendor,
                            systemImage: "building.2",
                            isSelected: viewModel.vendorFilter == vendor
                        ) { viewModel.vendorFilter = vendor }
                    }
                }
            }
        }

        Section("Network Role") {
            filterButton(
                title: "All Roles",
                systemImage: "point.3.connected.trianglepath.dotted",
                isSelected: viewModel.typeFilter == nil
            ) { viewModel.typeFilter = nil }
            if viewModel.typeFilter == .router || hasDevices(for: .router) {
                filterButton(
                    title: "Routers",
                    systemImage: "router",
                    isSelected: viewModel.typeFilter == .router
                ) { viewModel.typeFilter = .router }
            }
            if viewModel.typeFilter == .endDevice || hasDevices(for: .endDevice) {
                filterButton(
                    title: "End Devices",
                    systemImage: "leaf",
                    isSelected: viewModel.typeFilter == .endDevice
                ) { viewModel.typeFilter = .endDevice }
            }
        }

        Section("Recency") {
            Toggle("Show Recently Added", isOn: $viewModel.showRecents)
        }
    }

    private func hasDevices(for status: DeviceStatusFilter) -> Bool {
        filterStores.contains { viewModel.statusCount(for: status, store: $0) > 0 }
    }

    private func hasDevices(for category: Device.Category) -> Bool {
        filterStores.contains { viewModel.typeCount(for: category, store: $0) > 0 }
    }

    private func hasDevices(for type: DeviceType) -> Bool {
        filterStores.contains { viewModel.roleCount(for: type, store: $0) > 0 }
    }

    private func hasDevices(for vendor: String) -> Bool {
        filterStores.contains { viewModel.vendorCount(for: vendor, store: $0) > 0 }
    }

    private func hasDevices(on bridge: BridgeSession) -> Bool {
        !viewModel.filteredDevices(store: bridge.store).isEmpty
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
