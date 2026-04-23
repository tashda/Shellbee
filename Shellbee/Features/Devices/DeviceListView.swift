import SwiftUI

struct DeviceListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = DeviceListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var deviceToRename: Device?
    @State private var deviceToRemove: Device?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    @State private var showUpdateAllConfirm = false

    private var otaCapableDevices: [Device] {
        environment.store.devices.filter { $0.definition?.supportsOTA == true }
    }

    private var devicesWithUpdateAvailable: [Device] {
        environment.store.devices.filter {
            environment.store.state(for: $0.friendlyName).hasUpdateAvailable
        }
    }

    private var isGrouped: Bool {
        viewModel.groupByCategory && !viewModel.hasActiveFilter && viewModel.searchText.isEmpty
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if isGrouped {
                    let grouped = viewModel.categorizedDevices(store: environment.store)
                    ForEach(grouped, id: \.0) { (category, devices) in
                        Section {
                            ForEach(devices) { device in
                                deviceRow(for: device)
                            }
                        } header: {
                            Text(category.label)
                        }
                    }
                } else {
                    let devices = viewModel.filteredDevices(store: environment.store)
                    ForEach(devices) { device in
                        deviceRow(for: device)
                    }
                }
            }
            .listStyle(.insetGrouped)
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
                    firmwareMenu
                    sortMenu
                }
            }
            .refreshable { await environment.refreshBridgeData() }
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
            .onAppear {
                if let filter = environment.pendingDeviceFilter {
                    navigationPath = NavigationPath()
                    viewModel.applyQuickFilter(filter)
                    environment.pendingDeviceFilter = nil
                }
                if let name = environment.pendingDeviceNavigation,
                   let device = environment.store.device(named: name) {
                    navigationPath = NavigationPath()
                    navigationPath.append(device)
                    environment.pendingDeviceNavigation = nil
                }
            }
            .onChange(of: environment.pendingDeviceFilter) { _, newFilter in
                guard let filter = newFilter else { return }
                navigationPath = NavigationPath()
                viewModel.applyQuickFilter(filter)
                environment.pendingDeviceFilter = nil
            }
            .onChange(of: environment.pendingDeviceNavigation) { _, newName in
                guard let name = newName,
                      let device = environment.store.device(named: name) else { return }
                navigationPath = NavigationPath()
                navigationPath.append(device)
                environment.pendingDeviceNavigation = nil
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
        .confirmationDialog(
            "Update \(devicesWithUpdateAvailable.count) device\(devicesWithUpdateAvailable.count == 1 ? "" : "s")?",
            isPresented: $showUpdateAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Update All", role: .destructive) {
                for device in devicesWithUpdateAvailable {
                    viewModel.updateDevice(device, environment: environment)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Firmware updates run sequentially and can take several minutes per device. Devices may be briefly unresponsive during their update.")
        }
    }

    // MARK: - Firmware menu

    private var firmwareMenu: some View {
        let otaCount = otaCapableDevices.count
        let updateCount = devicesWithUpdateAvailable.count
        return Menu {
            Button {
                for device in otaCapableDevices {
                    viewModel.checkDeviceUpdate(device, environment: environment)
                }
            } label: {
                Label("Check All for Updates\(otaCount > 0 ? " (\(otaCount))" : "")", systemImage: "arrow.trianglehead.2.clockwise")
            }
            .disabled(otaCount == 0)

            Button {
                showUpdateAllConfirm = true
            } label: {
                Label("Update All Available\(updateCount > 0 ? " (\(updateCount))" : "")", systemImage: "arrow.up.circle")
            }
            .disabled(updateCount == 0)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "arrow.up.circle")
                if updateCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -2)
                }
            }
        }
        .accessibilityLabel("Firmware updates")
    }

    // MARK: - Row builder

    @ViewBuilder
    private func deviceRow(for device: Device) -> some View {
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

    // MARK: - Sort menu

    private var sortMenu: some View {
        Menu {
            Toggle(isOn: $viewModel.groupByCategory) {
                Label("Group by Type", systemImage: "square.grid.2x2")
            }

            Divider()

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
