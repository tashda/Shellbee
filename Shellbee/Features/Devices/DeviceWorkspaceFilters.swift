import SwiftUI

struct DeviceWorkspaceFilters: View {
    @Bindable var viewModel: DeviceListViewModel
    @Environment(AppEnvironment.self) private var environment

    private var connectedBridges: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    var body: some View {
        if connectedBridges.count >= 2 {
            Section("Bridge") {
                filterButton(
                    title: "All Bridges",
                    systemImage: "antenna.radiowaves.left.and.right",
                    isSelected: viewModel.bridgeFilter == nil
                ) { viewModel.bridgeFilter = nil }
                ForEach(connectedBridges, id: \.bridgeID) { bridge in
                    filterButton(
                        title: bridge.displayName,
                        systemImage: "antenna.radiowaves.left.and.right",
                        isSelected: viewModel.bridgeFilter == bridge.bridgeID
                    ) { viewModel.bridgeFilter = bridge.bridgeID }
                }
            }
        }

        Section("Availability & Updates") {
            ForEach(DeviceStatusFilter.allCases, id: \.self) { status in
                filterButton(
                    title: status.rawValue,
                    systemImage: status.systemImage,
                    isSelected: viewModel.statusFilter == status
                ) { viewModel.statusFilter = status }
            }
        }

        Section("Device Type") {
            filterButton(
                title: "All Types",
                systemImage: "square.grid.2x2",
                isSelected: viewModel.categoryFilter == nil
            ) { viewModel.categoryFilter = nil }
            ForEach(Device.Category.allCases, id: \.self) { category in
                filterButton(
                    title: category.label,
                    systemImage: category.systemImage,
                    isSelected: viewModel.categoryFilter == category
                ) { viewModel.categoryFilter = category }
            }
        }

        Section("Network Role") {
            filterButton(
                title: "All Roles",
                systemImage: "point.3.connected.trianglepath.dotted",
                isSelected: viewModel.typeFilter == nil
            ) { viewModel.typeFilter = nil }
            filterButton(
                title: "Routers",
                systemImage: "router",
                isSelected: viewModel.typeFilter == .router
            ) { viewModel.typeFilter = .router }
            filterButton(
                title: "End Devices",
                systemImage: "leaf",
                isSelected: viewModel.typeFilter == .endDevice
            ) { viewModel.typeFilter = .endDevice }
        }

        Section("Recency") {
            Toggle("Show Recently Added", isOn: $viewModel.showRecents)
        }

        if viewModel.hasActiveFilter {
            Section {
                Button("Clear Filters", role: .destructive) {
                    viewModel.statusFilter = .all
                    viewModel.categoryFilter = nil
                    viewModel.vendorFilter = nil
                    viewModel.typeFilter = nil
                    viewModel.bridgeFilter = nil
                }
            }
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
