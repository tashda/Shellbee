import SwiftUI

struct DeviceFilterMenu: View {
    @Bindable var viewModel: DeviceListViewModel
    let store: AppStore

    @Environment(AppEnvironment.self) private var environment
    @State private var snapshot = DeviceFilterMenuSnapshot.empty

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    var body: some View {
        Menu {
            if connectedSessions.count >= 2 {
                BridgeFilterMenu(selection: $viewModel.bridgeFilter, sessions: connectedSessions)
            }
            Menu {
                Picker("Status", selection: statusSelection) {
                    ForEach(snapshot.statuses, id: \.filter) { item in
                        Label(item.title, systemImage: item.systemImage)
                            .tag(item.filter)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                let active = viewModel.statusFilter != .all
                FilterSubmenuLabel(
                    name: "Status",
                    systemImage: "circle.grid.2x2",
                    value: active ? viewModel.statusFilter.rawValue : nil,
                    valueSystemImage: viewModel.statusFilter.systemImage
                )
            }

            if !snapshot.categories.isEmpty {
                Menu {
                    Picker("Type", selection: categorySelection) {
                        Label("All Types", systemImage: FilterMenuSymbol.all)
                            .tag(Device.Category?.none)
                        ForEach(snapshot.categories, id: \.category) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .tag(Device.Category?.some(item.category))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    FilterSubmenuLabel(
                        name: "Type",
                        systemImage: "tag",
                        value: viewModel.categoryFilter?.label,
                        valueSystemImage: viewModel.categoryFilter?.systemImage
                    )
                }
            }

            if !snapshot.vendors.isEmpty {
                Menu {
                    Picker("Manufacturer", selection: vendorSelection) {
                        Label("All Manufacturers", systemImage: FilterMenuSymbol.all)
                            .tag(String?.none)
                        ForEach(snapshot.vendors, id: \.vendor) { item in
                            Text(item.title)
                                .tag(String?.some(item.vendor))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    FilterSubmenuLabel(name: "Manufacturer", systemImage: "building.2", value: viewModel.vendorFilter)
                }
            }

            if !snapshot.roles.isEmpty {
                Menu {
                    Picker("Network Role", selection: roleSelection) {
                        Label("All Roles", systemImage: FilterMenuSymbol.all)
                            .tag(DeviceType?.none)
                        ForEach(snapshot.roles, id: \.type) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .tag(DeviceType?.some(item.type))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    FilterSubmenuLabel(
                        name: "Network Role",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        value: viewModel.typeFilter?.chipLabel
                    )
                }
            }

            ClearFiltersMenuItem(isActive: viewModel.hasActiveFilter) {
                viewModel.clearFilters()
                refreshSnapshot()
            }
        } label: {
            FilterMenuLabel(isActive: viewModel.hasActiveFilter)
        }
        .simultaneousGesture(TapGesture().onEnded { snapshot = .make(viewModel: viewModel, store: store) })
        .onAppear { snapshot = .make(viewModel: viewModel, store: store) }
    }

    private var statusSelection: Binding<DeviceStatusFilter> {
        Binding(
            get: { viewModel.statusFilter },
            set: {
                viewModel.statusFilter = $0
                refreshSnapshot()
            }
        )
    }

    private var categorySelection: Binding<Device.Category?> {
        Binding(
            get: { viewModel.categoryFilter },
            set: {
                viewModel.categoryFilter = $0
                refreshSnapshot()
            }
        )
    }

    private var vendorSelection: Binding<String?> {
        Binding(
            get: { viewModel.vendorFilter },
            set: {
                viewModel.vendorFilter = $0
                refreshSnapshot()
            }
        )
    }

    private var roleSelection: Binding<DeviceType?> {
        Binding(
            get: { viewModel.typeFilter },
            set: {
                viewModel.typeFilter = $0
                refreshSnapshot()
            }
        )
    }

    private func refreshSnapshot() {
        snapshot = .make(viewModel: viewModel, store: store)
    }
}

#Preview {
    Text("DeviceFilterMenu")
}
