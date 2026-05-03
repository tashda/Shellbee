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

    private var isMergedMode: Bool {
        environment.registry.sessions.values.filter(\.isConnected).count >= 2
    }

    var body: some View {
        if isMergedMode {
            mergedList
        } else {
            singleBridgeList
        }
    }

    // MARK: - Single-bridge mode (legacy path, unchanged)

    @ViewBuilder
    private var singleBridgeList: some View {
        List {
            if isGrouped {
                if viewModel.showRecents {
                    let recents = viewModel.recentDevices(store: environment.store)
                    if !recents.isEmpty {
                        Section {
                            ForEach(recents, id: \.ieeeAddress) { device in
                                deviceRow(for: device, store: environment.store, bridgeName: nil)
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
                            deviceRow(for: device, store: environment.store, bridgeName: nil)
                        }
                    } header: {
                        Text(category.label)
                    }
                }
            } else {
                let devices = viewModel.filteredDevices(store: environment.store)
                ForEach(devices) { device in
                    deviceRow(for: device, store: environment.store, bridgeName: nil)
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

    /// Apply search to the aggregated multi-bridge list. Status / category /
    /// vendor / type filters intentionally degrade to all-pass in merged mode —
    /// those filters are designed around per-bridge state semantics; doing
    /// proper merged filtering belongs in a follow-up.
    private func filteredMergedDevices() -> [BridgeBoundDevice] {
        let q = viewModel.searchText.lowercased()
        let all = environment.allDevices.filter { $0.device.type != .coordinator }
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
                if bound.device.interviewing { return true }
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
            // Route the row's actions at the device's own bridge — not the
            // currently-focused one. Each action calls
            // `environment.send(bridge:topic:payload:)` so the request lands on
            // the right WebSocket regardless of focus.
            HStack(alignment: .center, spacing: DesignTokens.Spacing.xs) {
                deviceRow(for: bound.device, store: session.store, bridgeName: bound.bridgeName, bridgeID: bound.bridgeID)
                BridgeBadge(
                    bridgeName: bound.bridgeName,
                    isFocused: environment.registry.primaryBridgeID == bound.bridgeID
                )
            }
            .simultaneousGesture(TapGesture().onEnded {
                if environment.registry.primaryBridgeID != bound.bridgeID {
                    environment.registry.setPrimary(bound.bridgeID)
                }
            })
        }
    }

    // MARK: - Row composition

    @ViewBuilder
    private func deviceRow(
        for device: Device,
        store: AppStore,
        bridgeName: String?,
        bridgeID: UUID? = nil
    ) -> some View {
        let state = store.state(for: device.friendlyName)
        let isAvailable = store.isAvailable(device.friendlyName)
        let otaStatus = store.otaStatus(for: device.friendlyName)
        DeviceListRow(
            device: device,
            state: state,
            isAvailable: isAvailable,
            otaStatus: otaStatus,
            checkResult: store.deviceCheckResults[device.friendlyName],
            isDeleting: store.pendingRemovals.contains(device.friendlyName),
            isIdentifying: store.identifyInProgress.contains(device.friendlyName),
            onRename: { onRename(device) },
            onRemove: { onRemove(device) },
            onReconfigure: { onPendingAlert(.reconfigure(device)) },
            onInterview: { onPendingAlert(.interview(device)) },
            onIdentify: {
                if let bridgeID {
                    // Route identify to the device's bridge in merged mode.
                    if !store.identifyInProgress.contains(device.friendlyName) {
                        store.identifyInProgress.insert(device.friendlyName)
                        environment.send(
                            bridge: bridgeID,
                            topic: Z2MTopics.deviceSet(device.friendlyName),
                            payload: .object(["identify": .string("identify")])
                        )
                        Task { [weak store] in
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run { _ = store?.identifyInProgress.remove(device.friendlyName) }
                        }
                    }
                } else {
                    environment.identifyDevice(device.friendlyName)
                }
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
