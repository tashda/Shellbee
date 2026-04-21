import SwiftUI

struct DeviceListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = DeviceListViewModel()
    @State private var deviceToRename: Device?
    @State private var deviceToRemove: Device?
    @State private var pendingDeviceAlert: PendingDeviceAlert?

    var body: some View {
        NavigationStack {
            List {
                let devices = viewModel.filteredDevices(store: environment.store)
                ForEach(devices) { device in
                    let state = environment.store.state(for: device.friendlyName)
                    let isAvailable = environment.store.isAvailable(device.friendlyName)
                    let otaStatus = environment.store.otaStatus(for: device.friendlyName)
                    DeviceListRow(
                        device: device,
                        state: state,
                        isAvailable: isAvailable,
                        otaStatus: otaStatus,
                        onRename: { deviceToRename = device },
                        onRemove: { deviceToRemove = device },
                        onReconfigure: { pendingDeviceAlert = .reconfigure(device) },
                        onInterview: { pendingDeviceAlert = .interview(device) },
                        onUpdate: state.hasUpdateAvailable
                            ? { viewModel.updateDevice(device, environment: environment) }
                            : nil,
                        onCheckUpdate: { viewModel.checkDeviceUpdate(device, environment: environment) }
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Device.self) { device in
                DeviceDetailView(device: device)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    DeviceFilterMenu(viewModel: viewModel, store: environment.store)
                    sortMenu
                }
            }
            .refreshable {
                try? await Task.sleep(for: .seconds(1))
            }
            .overlay {
                if environment.store.devices.isEmpty {
                    ContentUnavailableView(
                        "No Devices",
                        systemImage: "cpu",
                        description: Text("Devices will appear once connected to Zigbee2MQTT.")
                    )
                } else if !viewModel.searchText.isEmpty && viewModel.filteredDevices(store: environment.store).isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
            .task(id: environment.pendingDeviceFilter) {
                guard let filter = environment.pendingDeviceFilter else { return }
                viewModel.applyQuickFilter(filter)
                environment.pendingDeviceFilter = nil
            }
        }
        .sheet(item: $deviceToRename) { device in
            RenameDeviceSheet(device: device) { newName, updateHA in
                viewModel.renameDevice(device, to: newName, homeassistantRename: updateHA, environment: environment)
            }
        }
        .sheet(item: $deviceToRemove) { device in
            RemoveDeviceSheet(device: device) { force, block in
                viewModel.removeDevice(device, force: force, block: block, environment: environment)
            }
        }
        .alert(
            pendingDeviceAlert?.title ?? "",
            isPresented: Binding(
                get: { pendingDeviceAlert != nil },
                set: { if !$0 { pendingDeviceAlert = nil } }
            ),
            presenting: pendingDeviceAlert
        ) { alert in
            Button(alert.confirmTitle, role: alert.role) {
                switch alert {
                case .reconfigure(let device):
                    viewModel.reconfigureDevice(device, environment: environment)
                case .interview(let device):
                    viewModel.interviewDevice(device, environment: environment)
                }
                pendingDeviceAlert = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeviceAlert = nil
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sortOrder) {
                ForEach(DeviceSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button {
                viewModel.sortAscending.toggle()
            } label: {
                Label(
                    viewModel.sortAscending ? "Ascending" : "Descending",
                    systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                )
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}

#Preview {
    DeviceListView()
        .environment(AppEnvironment())
}
