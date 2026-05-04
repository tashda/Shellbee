import SwiftUI

private enum DeviceMenuDestination: Hashable {
    case settings, bind, reporting
}

struct DeviceDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    /// Phase 1 multi-bridge: the bridge that owns this device. Pushed as part
    /// of `DeviceRoute` from the list/notification layer so detail reads
    /// land on the correct store regardless of which bridge has focus.
    let bridgeID: UUID
    let device: Device
    @State private var showPairingSheet = false
    @State private var menuDestination: DeviceMenuDestination?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    @State private var showRemoveSheet = false
    @State private var showRenameSheet = false

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    var body: some View {
        let device = scope.store.devices.first { $0.ieeeAddress == self.device.ieeeAddress } ?? self.device
        let state = scope.store.state(for: device.friendlyName)
        let isAvailable = scope.store.isAvailable(device.friendlyName)
        let otaStatus = scope.store.otaStatus(for: device.friendlyName)

        List {
            DeviceCard(
                device: device,
                state: state,
                isAvailable: isAvailable,
                otaStatus: otaStatus,
                bridgeID: bridgeID,
                bridgeName: environment.registry.session(for: bridgeID)?.displayName,
                lastSeenEnabled: (scope.store.bridgeInfo?.config?.advanced?.lastSeen ?? "disable") != "disable",
                onRenameTapped: { showRenameSheet = true }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            heroAndSettingsSections(for: device, state: state)

            if device.definition != nil {
                Section("Documentation") {
                    NavigationLink {
                        DeviceDocView(bridgeID: bridgeID, device: device)
                    } label: {
                        Label("Device Documentation", systemImage: "doc.text")
                    }
                    Button {
                        showPairingSheet = true
                    } label: {
                        Label("How to Pair", systemImage: "personalhotspot")
                    }
                }
            }

            Section("Device Info") {
                CopyableRow(label: "Zigbee Model", value: device.modelId ?? "Unknown")
                CopyableRow(label: "IEEE Address", value: device.ieeeAddress)
                CopyableRow(label: "Network Address", value: "\(device.networkAddress)")
                CopyableRow(label: "MQTT Topic", value: "zigbee2mqtt/\(device.friendlyName)")
                if let fw = device.softwareBuildId {
                    CopyableRow(label: "Firmware", value: fw)
                }
            }

            if let description = device.definition?.description, !description.isEmpty {
                Section("About") {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            logsSection
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .toolbarBackground(.automatic, for: .navigationBar)
        .navigationTitle(device.friendlyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                deviceConfigMenu(for: device)
            }
        }
        .navigationDestination(item: $menuDestination) { destination in
            switch destination {
            case .settings:  DeviceSettingsView(bridgeID: bridgeID, device: device)
            case .bind:      DeviceBindView(bridgeID: bridgeID, device: device)
            case .reporting: DeviceReportingView(bridgeID: bridgeID, device: device)
            }
        }
        .sheet(isPresented: $showPairingSheet) {
            DevicePairingSheet(bridgeID: bridgeID, device: device)
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameDeviceSheet(device: device) { newName, updateHA in
                renameDevice(from: device.friendlyName, to: newName, homeassistantRename: updateHA)
            }
        }
        .sheet(isPresented: $showRemoveSheet) {
            RemoveDeviceSheet(device: device) { force, block in
                scope.send(topic: Z2MTopics.Request.deviceRemove, payload: .object([
                    "id": .string(device.friendlyName),
                    "force": .bool(force),
                    "block": .bool(block)
                ]))
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
                    scope.send(topic: Z2MTopics.Request.deviceConfigure, payload: .object(["id": .string(device.friendlyName)]))
                case .interview(let device):
                    scope.send(topic: Z2MTopics.Request.deviceInterview, payload: .object(["id": .string(device.friendlyName)]))
                }
                pendingDeviceAlert = nil
            }
            Button("Cancel", role: .cancel) { pendingDeviceAlert = nil }
        } message: { alert in
            Text(alert.message)
        }
    }

    /// Renders the hero card(s) plus any "leftover" exposes as native iOS
    /// Settings-style sections beneath. The cards stay exactly as they are;
    /// the sections handle configuration / advanced features that don't fit
    /// in the hero (LED, child lock, power-on behaviour, calibration, etc.).
    @ViewBuilder
    private func heroAndSettingsSections(for device: Device, state: [String: JSONValue]) -> some View {
        let send: (JSONValue) -> Void = { payload in
            scope.send(topic: Z2MTopics.deviceSet(device.friendlyName), payload: payload)
        }

        switch device.category {
        case .fan:
            if let ctx = FanControlContext(device: device, state: state) {
                Section {
                    FanControlCard(context: ctx, mode: .interactive, onSend: send, rendersSectionsInline: false)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                FanFeatureSections(context: ctx, mode: .interactive, onSend: send)
            } else {
                genericExposeSection(device: device, state: state, send: send)
            }

        case .light:
            let contexts = LightControlContext.contexts(for: device, state: state)
            if !contexts.isEmpty {
                Section {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        ForEach(contexts) { ctx in
                            LightControlCard(context: ctx, mode: .interactive, onSend: send,
                                             rendersAdvancedSheetsInline: false)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                ForEach(contexts) { ctx in
                    LightFeatureSections(context: ctx, onSend: send)
                }
            } else {
                genericExposeSection(device: device, state: state, send: send)
            }

        case .switchPlug:
            let contexts = SwitchControlContext.contexts(for: device, state: state)
            if !contexts.isEmpty {
                Section {
                    ExposeCardView(device: device, state: state, mode: .interactive, onSend: send)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let ctx = contexts.first {
                    SwitchFeatureSections(device: device, context: ctx, state: state, onSend: send)
                }
            } else {
                genericExposeSection(device: device, state: state, send: send)
            }

        case .climate:
            if let ctx = ClimateControlContext(device: device, state: state) {
                Section {
                    ClimateControlCard(context: ctx, mode: .interactive, onSend: send)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                ClimateFeatureSections(device: device, context: ctx, state: state, onSend: send)
            } else {
                genericExposeSection(device: device, state: state, send: send)
            }

        case .cover:
            let contexts = CoverControlContext.contexts(for: device, state: state)
            if !contexts.isEmpty {
                Section {
                    ExposeCardView(device: device, state: state, mode: .interactive, onSend: send)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let ctx = contexts.first {
                    CoverFeatureSections(device: device, context: ctx, state: state, onSend: send)
                }
            } else {
                genericExposeSection(device: device, state: state, send: send)
            }

        default:
            genericExposeSection(device: device, state: state, send: send)
        }
    }

    @ViewBuilder
    private func genericExposeSection(device: Device, state: [String: JSONValue], send: @escaping (JSONValue) -> Void) -> some View {
        Section {
            ExposeCardView(device: device, state: state, mode: .interactive, onSend: send)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private static let recentLogLimit = 5

    @ViewBuilder
    private var logsSection: some View {
        let deviceEntries = scope.store.logEntries.filter { $0.deviceName == device.friendlyName }
        let recent = Array(deviceEntries.prefix(Self.recentLogLimit))

        Section("Logs") {
            if deviceEntries.isEmpty {
                Text("No logs for this device yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { entry in
                    NavigationLink {
                        LogDetailView(bridgeID: bridgeID, entry: entry)
                    } label: {
                        LogRowView(entry: entry, store: scope.store, bridgeID: bridgeID)
                    }
                    .listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
                }
                NavigationLink {
                    DeviceLogsView(bridgeID: bridgeID, device: device)
                } label: {
                    Label("See All Logs", systemImage: "list.bullet")
                }
            }
        }
    }

    private func deviceConfigMenu(for device: Device) -> some View {
        let state = scope.store.state(for: device.friendlyName)
        let otaStatus = scope.store.otaStatus(for: device.friendlyName)
        let otaActive = otaStatus?.isActive == true
        let supportsOTA = device.definition?.supportsOTA == true
        let hasUpdateAvailable = state.hasUpdateAvailable
        let isBattery = (device.powerSource?.lowercased() ?? "").contains("battery")
        let isScheduled = otaStatus?.phase == .scheduled

        return Menu {
            Button { menuDestination = .settings } label: {
                Label("Device Settings", systemImage: "slider.horizontal.3")
            }
            Button { menuDestination = .bind } label: {
                Label("Bind", systemImage: "link")
            }
            Button { menuDestination = .reporting } label: {
                Label("Reporting", systemImage: "waveform")
            }
            if supportsOTA {
                Divider()
                if isScheduled {
                    Button { unscheduleUpdate(device) } label: {
                        Label("Cancel Scheduled Update", systemImage: "xmark.circle")
                    }
                } else if !otaActive {
                    Button { checkForUpdate(device) } label: {
                        Label("Check for Update", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if hasUpdateAvailable {
                        if isBattery {
                            Button { scheduleUpdate(device) } label: {
                                Label("Schedule Update", systemImage: "calendar.badge.clock")
                            }
                            Button { updateFirmware(device) } label: {
                                Label("Update Now", systemImage: "arrow.up.circle")
                            }
                        } else {
                            Button { updateFirmware(device) } label: {
                                Label("Update Now", systemImage: "arrow.up.circle")
                            }
                            Button { scheduleUpdate(device) } label: {
                                Label("Schedule Update", systemImage: "calendar.badge.clock")
                            }
                        }
                    }
                }
            }
            Divider()
            if device.supportsIdentify {
                Button {
                    identifyDevice(device.friendlyName)
                } label: {
                    let identifying = scope.store.identifyInProgress.contains(device.friendlyName)
                    Label(identifying ? "Identifying" : "Identify",
                          systemImage: identifying ? "wave.3.right" : "wave.3.right.circle")
                }
                .disabled(scope.store.identifyInProgress.contains(device.friendlyName))
            }
            Button { pendingDeviceAlert = .interview(device) } label: {
                Label("Interview", systemImage: "questionmark.circle")
            }
            Button { pendingDeviceAlert = .reconfigure(device) } label: {
                Label("Reconfigure", systemImage: "gearshape.fill")
            }
            Divider()
            Button(role: .destructive) { showRemoveSheet = true } label: {
                Label("Remove Device", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    private func checkForUpdate(_ device: Device) {
        Haptics.impact(.light)
        scope.store.startOTACheck(for: device.friendlyName)
        scope.send(
            topic: Z2MTopics.Request.deviceOTACheck,
            payload: .object(["id": .string(device.friendlyName)])
        )
    }

    private func updateFirmware(_ device: Device) {
        Haptics.impact(.medium)
        scope.store.startOTAUpdate(for: device.friendlyName)
        scope.send(
            topic: Z2MTopics.Request.deviceOTAUpdate,
            payload: .object(["id": .string(device.friendlyName)])
        )
    }

    private func scheduleUpdate(_ device: Device) {
        Haptics.impact(.medium)
        scope.store.startOTASchedule(for: device.friendlyName)
        scope.send(
            topic: Z2MTopics.Request.deviceOTASchedule,
            payload: .object(["id": .string(device.friendlyName)])
        )
    }

    private func unscheduleUpdate(_ device: Device) {
        Haptics.impact(.light)
        scope.store.cancelOTASchedule(for: device.friendlyName)
        scope.send(
            topic: Z2MTopics.Request.deviceOTAUnschedule,
            payload: .object(["id": .string(device.friendlyName)])
        )
        // Z2M leaves update.state at "idle" after unschedule — re-check so
        // the device returns to "available" and stays in the Updates filter.
        scope.store.startOTACheck(for: device.friendlyName)
        scope.send(
            topic: Z2MTopics.Request.deviceOTACheck,
            payload: .object(["id": .string(device.friendlyName)])
        )
    }

    private func renameDevice(from: String, to: String, homeassistantRename: Bool) {
        let trimmed = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != from else { return }
        scope.store.optimisticRename(from: from, to: trimmed)
        scope.send(topic: Z2MTopics.Request.deviceRename, payload: .object([
            "from": .string(from),
            "to": .string(trimmed),
            "homeassistant_rename": .bool(homeassistantRename)
        ]))
    }

    private func identifyDevice(_ friendlyName: String) {
        let store = scope.store
        guard !store.identifyInProgress.contains(friendlyName) else { return }
        store.identifyInProgress.insert(friendlyName)
        scope.send(
            topic: Z2MTopics.deviceSet(friendlyName),
            payload: .object(["identify": .string("identify")])
        )
        Task { [weak store] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { _ = store?.identifyInProgress.remove(friendlyName) }
        }
    }
}

#Preview {
    NavigationStack {
        DeviceDetailView(bridgeID: UUID(), device: .preview)
            .environment(AppEnvironment())
    }
}
