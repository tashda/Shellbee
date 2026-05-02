import SwiftUI

struct DeviceListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = DeviceListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var deviceToRename: Device?
    @State private var deviceToRemove: Device?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    @State private var showPairingWizard = false

    private var isGrouped: Bool {
        viewModel.groupByCategory && !viewModel.hasActiveFilter && viewModel.searchText.isEmpty
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            DeviceListContent(
                viewModel: viewModel,
                isGrouped: isGrouped,
                onRename: { deviceToRename = $0 },
                onRemove: { deviceToRemove = $0 },
                onPendingAlert: { pendingDeviceAlert = $0 }
            )
            .listStyle(.insetGrouped)
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Device.self) { device in
                DeviceDetailView(device: device)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .minimizeSearchToolbarIfAvailable()
            .toolbar {
                BridgeSwitcherToolbarItem()
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showPairingWizard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Device")
                    DeviceFilterMenu(viewModel: viewModel, store: environment.store)
                    DeviceFirmwareMenu()
                    sortMenu
                }
            }
            .refreshable { await environment.refreshBridgeData() }
            .onAppear {
                if let filter = environment.pendingDeviceFilter {
                    navigationPath = NavigationPath()
                    viewModel.applyQuickFilter(filter)
                    environment.pendingDeviceFilter = nil
                }
                if let name = environment.pendingDeviceNavigation,
                   let device = environment.store.device(named: name) {
                    environment.pendingDeviceNavigation = nil
                    pushDeviceResettingPath(device)
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
                environment.pendingDeviceNavigation = nil
                pushDeviceResettingPath(device)
            }
        }
        .sheet(isPresented: $showPairingWizard) {
            PairingWizardView()
                .environment(environment)
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

    // Pop to root then push on the next runloop. Replacing and appending the
    // path in the same cycle raised AnyNavigationPath.comparisonTypeMismatch
    // when the stack already contained a Device entry.
    private func pushDeviceResettingPath(_ device: Device) {
        if !navigationPath.isEmpty {
            navigationPath.removeLast(navigationPath.count)
        }
        Task { @MainActor in
            navigationPath.append(device)
        }
    }

    // MARK: - Sort menu

    private var sortMenu: some View {
        Menu {
            Toggle(isOn: $viewModel.groupByCategory) {
                Label("Group by Type", systemImage: "square.grid.2x2")
            }
            Toggle(isOn: $viewModel.showRecents) {
                Label("Show Recents", systemImage: "sparkles")
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

// Isolating the per-device state observation in a child view keeps OTA
// progress ticks from invalidating the parent's `.toolbar` modifier, which
// would otherwise dismiss any open Filter submenu mid-interaction.
private struct DeviceListContent: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: DeviceListViewModel
    let isGrouped: Bool
    let onRename: (Device) -> Void
    let onRemove: (Device) -> Void
    let onPendingAlert: (PendingDeviceAlert) -> Void

    var body: some View {
        List {
            if isGrouped {
                if viewModel.showRecents {
                    let recents = viewModel.recentDevices(store: environment.store)
                    if !recents.isEmpty {
                        Section {
                            ForEach(recents, id: \.ieeeAddress) { device in
                                deviceRow(for: device)
                            }
                        } header: {
                            Text("Recently Added")
                        }
                    }
                }
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
    }

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
            checkResult: environment.store.deviceCheckResults[device.friendlyName],
            isDeleting: environment.store.pendingRemovals.contains(device.friendlyName),
            isIdentifying: environment.store.identifyInProgress.contains(device.friendlyName),
            onRename: { onRename(device) },
            onRemove: { onRemove(device) },
            onReconfigure: { onPendingAlert(.reconfigure(device)) },
            onInterview: { onPendingAlert(.interview(device)) },
            onIdentify: { environment.identifyDevice(device.friendlyName) },
            onUpdate: state.hasUpdateAvailable
                ? { viewModel.updateDevice(device, environment: environment) }
                : nil,
            onCheckUpdate: { viewModel.checkDeviceUpdate(device, environment: environment) },
            onSchedule: state.hasUpdateAvailable
                ? { viewModel.scheduleDeviceUpdate(device, environment: environment) }
                : nil,
            onUnschedule: { viewModel.unscheduleDeviceUpdate(device, environment: environment) }
        )
    }
}

#Preview {
    DeviceListView()
        .environment(AppEnvironment())
}
