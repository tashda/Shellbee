import SwiftUI

struct DeviceFilterMenu: View {
    @Bindable var viewModel: DeviceListViewModel
    let store: AppStore

    @State private var snapshot = DeviceFilterMenuSnapshot.empty

    var body: some View {
        Menu {
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
                Label(
                    active ? "Status: \(viewModel.statusFilter.rawValue)" : "Status",
                    systemImage: active ? viewModel.statusFilter.systemImage : "circle.grid.2x2"
                )
            }

            if !snapshot.categories.isEmpty {
                Menu {
                    Picker("Type", selection: categorySelection) {
                        Label("All Types", systemImage: "square.grid.2x2")
                            .tag(Device.Category?.none)
                        ForEach(snapshot.categories, id: \.category) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .tag(Device.Category?.some(item.category))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    if let category = viewModel.categoryFilter {
                        Label("Type: \(category.label)", systemImage: category.systemImage)
                    } else {
                        Label("Type", systemImage: "tag")
                    }
                }
            }

            if !snapshot.vendors.isEmpty {
                Menu {
                    Picker("Manufacturer", selection: vendorSelection) {
                        Label("All Manufacturers", systemImage: "building.2")
                            .tag(String?.none)
                        ForEach(snapshot.vendors, id: \.vendor) { item in
                            Text(item.title)
                                .tag(String?.some(item.vendor))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    if let vendor = viewModel.vendorFilter {
                        Label(vendor, systemImage: "building.2.fill")
                    } else {
                        Label("Manufacturer", systemImage: "building.2")
                    }
                }
            }

            if !snapshot.roles.isEmpty {
                Menu {
                    Picker("Network Role", selection: roleSelection) {
                        Label("All Roles", systemImage: "point.3.connected.trianglepath.dotted")
                            .tag(DeviceType?.none)
                        ForEach(snapshot.roles, id: \.type) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .tag(DeviceType?.some(item.type))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    if let type = viewModel.typeFilter {
                        Label("Role: \(type.chipLabel)", systemImage: "point.3.connected.trianglepath.dotted")
                    } else {
                        Label("Network Role", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                }
            }

            if viewModel.hasActiveFilter {
                Divider()
                Button(role: .destructive) {
                    viewModel.statusFilter = .all
                    viewModel.categoryFilter = nil
                    viewModel.vendorFilter = nil
                    viewModel.typeFilter = nil
                    refreshSnapshot()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant(viewModel.hasActiveFilter ? .fill : .none)
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
