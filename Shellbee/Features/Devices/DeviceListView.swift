import SwiftUI

struct DeviceListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = DeviceListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var deviceToRename: BridgeBoundDevice?
    @State private var deviceToRemove: BridgeBoundDevice?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    @State private var pendingAlertBridgeID: UUID?
    @State private var showPairingWizard = false

    private var isGrouped: Bool {
        viewModel.groupByCategory
    }

    /// The bridge that toolbar actions (firmware menu, refresh) target. In
    /// merged mode this defaults to the user's filter selection or the
    /// focused bridge; in single-bridge mode it's the only connected bridge.
    /// `nil` only when there are zero connected bridges.
    private var toolbarBridgeID: UUID? {
        if let id = viewModel.bridgeFilter, environment.registry.session(for: id) != nil { return id }
        if let id = environment.registry.primaryBridgeID, environment.registry.session(for: id) != nil { return id }
        return environment.registry.orderedSessions.first(where: \.isConnected)?.bridgeID
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            DeviceListContent(
                viewModel: viewModel,
                isGrouped: isGrouped,
                onRename: { deviceToRename = $0 },
                onRemove: { deviceToRemove = $0 },
                onPendingAlert: { alert, bridgeID in
                    pendingDeviceAlert = alert
                    pendingAlertBridgeID = bridgeID
                }
            )
            .listStyle(.insetGrouped)
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: DeviceRoute.self) { route in
                DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .minimizeSearchToolbarIfAvailable()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showPairingWizard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Device")
                    if let toolbarID = toolbarBridgeID {
                        DeviceFilterMenu(viewModel: viewModel, store: environment.scope(for: toolbarID).store)
                        DeviceFirmwareMenu(bridgeID: toolbarID)
                    }
                    sortMenu
                }
            }
            .refreshable {
                if let id = toolbarBridgeID {
                    await environment.refreshBridgeData(bridgeID: id)
                }
            }
            .onAppear {
                if let filter = environment.pendingDeviceFilter {
                    navigationPath = NavigationPath()
                    viewModel.applyQuickFilter(filter)
                    environment.pendingDeviceFilter = nil
                }
                if let route = environment.pendingDeviceNavigation {
                    environment.pendingDeviceNavigation = nil
                    pushDeviceResettingPath(route)
                }
            }
            .onChange(of: environment.pendingDeviceFilter) { _, newFilter in
                guard let filter = newFilter else { return }
                navigationPath = NavigationPath()
                viewModel.applyQuickFilter(filter)
                environment.pendingDeviceFilter = nil
            }
            .onChange(of: environment.pendingDeviceNavigation) { _, newRoute in
                guard let route = newRoute else { return }
                environment.pendingDeviceNavigation = nil
                pushDeviceResettingPath(route)
            }
        }
        .sheet(isPresented: $showPairingWizard) {
            PairingWizardView()
                .environment(environment)
        }
        .sheet(item: $deviceToRename) { bound in
            RenameDeviceSheet(device: bound.device) { newName, updateHA in
                viewModel.renameDevice(bound.device, to: newName, homeassistantRename: updateHA, environment: environment, bridgeID: bound.bridgeID)
            }
        }
        .sheet(item: $deviceToRemove) { bound in
            RemoveDeviceSheet(device: bound.device) { force, block in
                viewModel.removeDevice(bound.device, force: force, block: block, environment: environment, bridgeID: bound.bridgeID)
            }
        }
        .alert(
            pendingDeviceAlert?.title ?? "",
            isPresented: Binding(
                get: { pendingDeviceAlert != nil },
                set: { if !$0 { pendingDeviceAlert = nil; pendingAlertBridgeID = nil } }
            ),
            presenting: pendingDeviceAlert
        ) { alert in
            Button(alert.confirmTitle, role: alert.role) {
                if let bridgeID = pendingAlertBridgeID {
                    switch alert {
                    case .reconfigure(let device):
                        viewModel.reconfigureDevice(device, environment: environment, bridgeID: bridgeID)
                    case .interview(let device):
                        viewModel.interviewDevice(device, environment: environment, bridgeID: bridgeID)
                    }
                }
                pendingDeviceAlert = nil
                pendingAlertBridgeID = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeviceAlert = nil
                pendingAlertBridgeID = nil
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    // Pop to root then push on the next runloop. Replacing and appending the
    // path in the same cycle raised AnyNavigationPath.comparisonTypeMismatch
    // when the stack already contained a Device entry.
    private func pushDeviceResettingPath(_ route: DeviceRoute) {
        if !navigationPath.isEmpty {
            navigationPath.removeLast(navigationPath.count)
        }
        Task { @MainActor in
            navigationPath.append(route)
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
    let onRename: (BridgeBoundDevice) -> Void
    let onRemove: (BridgeBoundDevice) -> Void
    /// Phase 1 multi-bridge: the bridgeID is required so reconfigure/interview
    /// alerts route to the right bridge.
    let onPendingAlert: (PendingDeviceAlert, UUID) -> Void

    private var isMergedMode: Bool {
        environment.registry.sessions.values.filter(\.isConnected).count >= 2
    }

    /// In single-bridge mode, the only connected session's id (used to wrap
    /// every device into a `BridgeBoundDevice` so the row, callbacks, and
    /// nav route all carry the same bridge identity).
    private var singleBridgeID: UUID? {
        environment.registry.orderedSessions.first(where: \.isConnected)?.bridgeID
    }

    var body: some View {
        if isMergedMode {
            mergedList
        } else {
            singleBridgeList
        }
    }

    // MARK: - Single-bridge mode

    @ViewBuilder
    private var singleBridgeList: some View {
        // No connected session yet (cold start, between disconnect-reconnect).
        // The container view shows ContentUnavailable below.
        if let bridgeID = singleBridgeID,
           let session = environment.registry.session(for: bridgeID) {
            singleBridgeListBody(bridgeID: bridgeID, store: session.store, bridgeName: session.displayName)
        } else {
            List {
                EmptyView()
            }
            .overlay {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "cpu",
                    description: Text("Devices will appear once connected to Zigbee2MQTT.")
                )
            }
        }
    }

    @ViewBuilder
    private func singleBridgeListBody(bridgeID: UUID, store: AppStore, bridgeName: String) -> some View {
        List {
            if isGrouped {
                if viewModel.showRecents {
                    let recents = viewModel.recentDevices(store: store)
                    if !recents.isEmpty {
                        Section {
                            ForEach(recents, id: \.ieeeAddress) { device in
                                deviceRow(for: device, store: store, bridgeName: bridgeName, bridgeID: bridgeID)
                            }
                        } header: {
                            Text("Recently Added")
                        }
                    }
                }
                let grouped = viewModel.categorizedDevices(store: store)
                ForEach(grouped, id: \.0) { (category, devices) in
                    Section {
                        ForEach(devices) { device in
                            deviceRow(for: device, store: store, bridgeName: bridgeName, bridgeID: bridgeID)
                        }
                    } header: {
                        Text(category.label)
                    }
                }
            } else {
                let devices = viewModel.filteredDevices(store: store)
                ForEach(devices) { device in
                    deviceRow(for: device, store: store, bridgeName: bridgeName, bridgeID: bridgeID)
                }
            }
        }
        .overlay {
            if store.devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "cpu",
                    description: Text("Devices will appear once connected to Zigbee2MQTT.")
                )
            } else if !viewModel.searchText.isEmpty && viewModel.filteredDevices(store: store).isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    // MARK: - Merged multi-bridge mode

    @ViewBuilder
    private var mergedList: some View {
        let allBound = filteredMergedDevices()
        List {
            if viewModel.showRecents {
                let recents = recentMergedDevices()
                if !recents.isEmpty {
                    Section {
                        ForEach(recents) { bound in
                            mergedRow(for: bound)
                        }
                    } header: {
                        Text("Recently Added")
                    }
                }
            }

            if isGrouped {
                let grouped = Dictionary(grouping: allBound) { $0.device.category }
                ForEach(Device.Category.allCases.filter { grouped[$0] != nil }, id: \.self) { category in
                    Section {
                        ForEach(grouped[category] ?? []) { bound in
                            mergedRow(for: bound)
                        }
                    } header: {
                        Text(category.label)
                    }
                }
            } else {
                ForEach(allBound) { bound in
                    mergedRow(for: bound)
                }
            }
        }
        .overlay {
            if environment.allDevices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "cpu",
                    description: Text("Devices will appear once a bridge is connected.")
                )
            } else if !viewModel.searchText.isEmpty && allBound.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    /// Apply the full filter set to the aggregated multi-bridge list. Status
    /// filtering resolves state/availability/OTA from each row's owning bridge.
    private func filteredMergedDevices() -> [BridgeBoundDevice] {
        let q = viewModel.searchText.lowercased()
        var all = environment.allDevices.filter { $0.device.type != .coordinator }
        if let bridgeID = viewModel.bridgeFilter {
            all = all.filter { $0.bridgeID == bridgeID }
        }

        if let condition = viewModel.statusFilter.condition {
            all = all.filter { bound in
                guard let store = environment.registry.session(for: bound.bridgeID)?.store else { return false }
                return condition.matches(
                    device: bound.device,
                    state: store.state(for: bound.device.friendlyName),
                    isAvailable: store.isAvailable(bound.device.friendlyName),
                    otaStatus: store.otaStatus(for: bound.device.friendlyName)
                )
            }
        }

        if let category = viewModel.categoryFilter {
            all = all.filter { $0.device.category == category }
        }
        if let vendor = viewModel.vendorFilter {
            all = all.filter { $0.device.definition?.vendor == vendor }
        }
        if let type = viewModel.typeFilter {
            all = all.filter { $0.device.type == type }
        }

        let filtered: [BridgeBoundDevice] = q.isEmpty
        ? all
        : all.filter { bound in
            bound.device.friendlyName.lowercased().contains(q)
                || bound.device.description?.lowercased().contains(q) == true
                || bound.device.definition?.vendor.lowercased().contains(q) == true
                || bound.device.definition?.model.lowercased().contains(q) == true
                || bound.bridgeName.lowercased().contains(q)
        }
        return sortedMerged(filtered)
    }

    private func recentMergedDevices() -> [BridgeBoundDevice] {
        let cutoff = Date().addingTimeInterval(-DeviceListViewModel.recentWindow)
        return environment.allDevices
            .filter { $0.device.type != .coordinator }
            .filter { bound in
                if bound.device.isInterviewing { return true }
                let store = environment.registry.session(for: bound.bridgeID)?.store
                if let joined = store?.deviceFirstSeen[bound.device.ieeeAddress], joined >= cutoff {
                    return true
                }
                return false
            }
            .sorted { lhs, rhs in
                let lStore = environment.registry.session(for: lhs.bridgeID)?.store
                let rStore = environment.registry.session(for: rhs.bridgeID)?.store
                let lt = lStore?.deviceFirstSeen[lhs.device.ieeeAddress] ?? .distantPast
                let rt = rStore?.deviceFirstSeen[rhs.device.ieeeAddress] ?? .distantPast
                if lt != rt { return lt > rt }
                return lhs.device.friendlyName.localizedCompare(rhs.device.friendlyName) == .orderedAscending
            }
    }

    private func sortedMerged(_ items: [BridgeBoundDevice]) -> [BridgeBoundDevice] {
        items.sorted { a, b in
            switch viewModel.sortOrder {
            case .name, .lastSeen:
                let cmp = a.device.friendlyName.localizedCompare(b.device.friendlyName)
                return viewModel.sortAscending ? cmp == .orderedAscending : cmp == .orderedDescending
            case .linkQuality:
                let aStore = environment.registry.session(for: a.bridgeID)?.store
                let bStore = environment.registry.session(for: b.bridgeID)?.store
                let aLQI = aStore?.state(for: a.device.friendlyName).linkQuality ?? -1
                let bLQI = bStore?.state(for: b.device.friendlyName).linkQuality ?? -1
                return viewModel.sortAscending ? aLQI > bLQI : aLQI < bLQI
            case .battery:
                let aStore = environment.registry.session(for: a.bridgeID)?.store
                let bStore = environment.registry.session(for: b.bridgeID)?.store
                let aBatt = aStore?.state(for: a.device.friendlyName).battery ?? 101
                let bBatt = bStore?.state(for: b.device.friendlyName).battery ?? 101
                return viewModel.sortAscending ? aBatt < bBatt : aBatt > bBatt
            }
        }
    }

    @ViewBuilder
    private func mergedRow(for bound: BridgeBoundDevice) -> some View {
        if let session = environment.registry.session(for: bound.bridgeID) {
            // Phase 1: the row's NavigationLink pushes a `DeviceRoute` carrying
            // `bound.bridgeID`, so DeviceDetailView reads from the device's
            // bridge directly — no `setPrimary()` workaround needed.
            deviceRow(for: bound.device, store: session.store, bridgeName: bound.bridgeName, bridgeID: bound.bridgeID)
        }
    }

    // MARK: - Row composition

    @ViewBuilder
    private func deviceRow(
        for device: Device,
        store: AppStore,
        bridgeName: String,
        bridgeID: UUID
    ) -> some View {
        let state = store.state(for: device.friendlyName)
        let isAvailable = store.isAvailable(device.friendlyName)
        let otaStatus = store.otaStatus(for: device.friendlyName)
        let bound = BridgeBoundDevice(bridgeID: bridgeID, bridgeName: bridgeName, device: device)
        DeviceListRow(
            device: device,
            state: state,
            isAvailable: isAvailable,
            otaStatus: otaStatus,
            checkResult: store.deviceCheckResults[device.friendlyName],
            isDeleting: store.pendingRemovals.contains(device.friendlyName),
            isIdentifying: store.identifyInProgress.contains(device.friendlyName),
            bridgeID: bridgeID,
            bridgeName: bridgeName,
            onRename: { onRename(bound) },
            onRemove: { onRemove(bound) },
            onReconfigure: { onPendingAlert(.reconfigure(device), bridgeID) },
            onInterview: { onPendingAlert(.interview(device), bridgeID) },
            onIdentify: {
                environment.scope(for: bridgeID).identifyDevice(device.friendlyName)
            },
            onUpdate: state.hasUpdateAvailable
                ? { viewModel.updateDevice(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            onCheckUpdate: { viewModel.checkDeviceUpdate(device, environment: environment, bridgeID: bridgeID) },
            onSchedule: state.hasUpdateAvailable
                ? { viewModel.scheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            onUnschedule: { viewModel.unscheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
        )
    }
}

#Preview {
    DeviceListView()
        .environment(AppEnvironment())
}
