import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isPermitJoinConfigPresented = false
    @State private var isPermitJoinActivePresented = false
    @State private var showingRestartAlert = false
    @State private var pendingRestartBridgeID: UUID?
    @State private var showingMeshDetail = false

    /// Active permit-join state derived from bridgeInfo so the toolbar
    /// sheet shows the correct countdown / via-target regardless of where
    /// permit-join was started (Home toolbar, Add Devices wizard, an
    /// external Z2M client, etc.).
    private var permitJoinTotalDuration: Int {
        environment.store.bridgeInfo?.permitJoinTimeout ?? 0
    }

    private var permitJoinStartTime: Date? {
        guard let end = environment.store.bridgeInfo?.permitJoinEnd,
              permitJoinTotalDuration > 0 else { return nil }
        let endSeconds = TimeInterval(end) / 1000
        return Date(timeIntervalSince1970: endSeconds - TimeInterval(permitJoinTotalDuration))
    }

    private var permitJoinTargetName: String? {
        environment.store.bridgeInfo?.permitJoinTarget
    }

    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount: Int = HomeSettings.recentEventsCountDefault
    @State private var showingAllLogs = false
    @State private var layout = HomeLayoutStore()

    /// Per-bridge entries for the Home Bridge card. Always includes every
    /// session — even ones that are reconnecting or offline — so the card can
    /// surface their status. In single-bridge mode this is just one entry, and
    /// the card renders the legacy layout.
    private var bridgeCardEntries: [HomeBridgeCardEntry] {
        let primaryID = environment.registry.primaryBridgeID
        return environment.registry.orderedSessions.map { session in
            HomeBridgeCardEntry(
                id: session.bridgeID,
                name: session.displayName,
                isFocused: session.bridgeID == primaryID,
                connectionState: session.connectionState,
                isWebSocketConnected: session.store.isConnected,
                isBridgeOnline: session.store.bridgeOnline,
                info: session.store.bridgeInfo,
                health: session.store.bridgeHealth
            )
        }
    }

    private var snapshot: HomeSnapshot {
        // Phase 2 multi-bridge: with 2+ bridges connected, aggregate every
        // session's devices, groups, and OTA state so the Home cards show
        // totals across the user's entire network. Bridge-metadata fields
        // (version, coordinator, channel, pan id) reflect the focused bridge —
        // they're inherently per-bridge and don't aggregate cleanly. The
        // Bridge card shows "Multiple bridges" treatment in merged mode via
        // its own rendering.
        let connected = environment.registry.sessions.values.filter(\.isConnected)
        let isMerged = connected.count >= 2

        if isMerged {
            let allDevices = connected.flatMap { $0.store.devices }
            let mergedAvailability = connected.reduce(into: [String: Bool]()) { acc, s in
                acc.merge(s.store.deviceAvailability) { existing, _ in existing }
            }
            let mergedStates = connected.reduce(into: [String: [String: JSONValue]]()) { acc, s in
                acc.merge(s.store.deviceStates) { existing, _ in existing }
            }
            let mergedOTA = connected.reduce(into: [String: OTAUpdateStatus]()) { acc, s in
                acc.merge(s.store.otaUpdates) { existing, _ in existing }
            }
            let totalGroups = connected.reduce(0) { $0 + $1.store.groups.count }
            let primary = environment.registry.primary

            return HomeSnapshot(
                devices: allDevices,
                availability: mergedAvailability,
                states: mergedStates,
                otaStatuses: mergedOTA,
                isConnected: connected.contains { $0.store.isConnected },
                isBridgeOnline: connected.allSatisfy { $0.store.bridgeOnline },
                groupCount: totalGroups,
                bridgeVersion: primary?.store.bridgeInfo?.version,
                bridgeCommit: primary?.store.bridgeInfo?.commit,
                coordinatorType: primary?.store.bridgeInfo?.coordinator.type,
                coordinatorIEEEAddress: primary?.store.bridgeInfo?.coordinator.ieeeAddress,
                networkChannel: primary?.store.bridgeInfo?.network?.channel,
                panID: primary?.store.bridgeInfo?.network?.panID,
                isPermitJoinActive: connected.contains { $0.store.bridgeInfo?.permitJoin == true },
                permitJoinEnd: primary?.store.bridgeInfo?.permitJoinEnd,
                restartRequired: connected.contains { $0.store.bridgeInfo?.restartRequired == true }
            )
        }

        return HomeSnapshot(
            devices: environment.store.devices,
            availability: environment.store.deviceAvailability,
            states: environment.store.deviceStates,
            otaStatuses: environment.store.otaUpdates,
            isConnected: environment.store.isConnected,
            isBridgeOnline: environment.store.bridgeOnline,
            groupCount: environment.store.groups.count,
            bridgeVersion: environment.store.bridgeInfo?.version,
            bridgeCommit: environment.store.bridgeInfo?.commit,
            coordinatorType: environment.store.bridgeInfo?.coordinator.type,
            coordinatorIEEEAddress: environment.store.bridgeInfo?.coordinator.ieeeAddress,
            networkChannel: environment.store.bridgeInfo?.network?.channel,
            panID: environment.store.bridgeInfo?.network?.panID,
            isPermitJoinActive: environment.store.bridgeInfo?.permitJoin ?? false,
            permitJoinEnd: environment.store.bridgeInfo?.permitJoinEnd,
            restartRequired: environment.store.bridgeInfo?.restartRequired ?? false
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.visibleOrder) { id in
                        HomeCardSlot(
                            card: id,
                            isEditing: layout.isEditing,
                            onHide: {
                                withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                                    layout.hide(id)
                                }
                            },
                            onEnterEdit: {
                                withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                                    layout.isEditing = true
                                }
                            }
                        ) {
                            cardView(for: id)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: DesignTokens.Spacing.sm,
                            leading: DesignTokens.Spacing.lg,
                            bottom: DesignTokens.Spacing.sm,
                            trailing: DesignTokens.Spacing.lg
                        ))
                    }
                    .onMove { source, destination in
                        layout.move(from: source, to: destination)
                    }
                }

                if layout.isEditing && !layout.hidden.isEmpty {
                    Section {
                        HomeAddCardsSection(
                            hidden: HomeCardID.allCases.filter { layout.hidden.contains($0) }
                        ) { card in
                            withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                                layout.show(card)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: DesignTokens.Spacing.md,
                            leading: DesignTokens.Spacing.lg,
                            bottom: DesignTokens.Spacing.lg,
                            trailing: DesignTokens.Spacing.lg
                        ))
                    }
                }

                if layout.visibleOrder.isEmpty {
                    emptyLayoutState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(layout.isEditing ? .active : .inactive))
            .background(HomeBackgroundGradient().ignoresSafeArea())
            .navigationDestination(isPresented: $showingAllLogs) {
                LogsView()
            }
            .navigationDestination(isPresented: $showingMeshDetail) {
                MeshDetailView(snapshot: snapshot)
            }
            .task(id: environment.store.isConnected) {
                guard environment.store.isConnected else { return }
                environment.send(topic: Z2MTopics.Request.healthCheck, payload: .object([:]))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if layout.isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                                layout.isEditing = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        PermitJoinToolbarButton(isActive: snapshot.isPermitJoinActive) {
                            if snapshot.isPermitJoinActive {
                                isPermitJoinActivePresented = true
                            } else {
                                isPermitJoinConfigPresented = true
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isPermitJoinConfigPresented) {
                PermitJoinSheet(onConfirm: startPermitJoin)
                    .environment(environment)
            }
            .sheet(isPresented: $isPermitJoinActivePresented) {
                PermitJoinActiveSheet(
                    startTime: permitJoinStartTime,
                    totalDuration: permitJoinTotalDuration,
                    targetName: permitJoinTargetName,
                    onStop: { sendPermitJoin(duration: 0, deviceName: nil, bridgeID: nil) }
                )
            }
            .alert("Restart Bridge?", isPresented: $showingRestartAlert) {
                Button("Restart", role: .destructive) {
                    if let id = pendingRestartBridgeID {
                        environment.restartBridge(id)
                    } else {
                        environment.restartBridge()
                    }
                    pendingRestartBridgeID = nil
                }
                Button("Cancel", role: .cancel) { pendingRestartBridgeID = nil }
            } message: {
                Text("Restarting the bridge will apply pending configuration changes and temporarily disconnect all Zigbee devices.")
            }
        }
    }

    @ViewBuilder
    private func cardView(for id: HomeCardID) -> some View {
        switch id {
        case .bridge:
            HomeBridgeCard(
                entries: bridgeCardEntries,
                onRestart: { id in
                    pendingRestartBridgeID = id
                    showingRestartAlert = true
                },
                onSelectBridge: bridgeCardEntries.count >= 2 ? { id in
                    if environment.registry.primaryBridgeID != id {
                        environment.registry.setPrimary(id)
                    }
                } : nil
            )
        case .devices:
            HomeDevicesCard(snapshot: snapshot) {
                environment.showDevices(filter: .all)
            } onFilter: {
                environment.showDevices(filter: $0)
            }
        case .groups:
            HomeGroupsCard(count: environment.store.groups.count) {
                environment.selectedTab = .groups
            }
        case .mesh:
            HomeMeshCard(snapshot: snapshot) {
                showingMeshDetail = true
            } onFilter: {
                environment.showDevices(filter: $0)
            }
        case .recentEvents:
            HomeLogsCard(
                entries: Array(environment.store.logEntries.prefix(recentEventsCount)),
                onOpenEntry: { entry in
                    environment.pendingLogSheet = LogSheetRequest(entryIDs: [entry.id])
                },
                onOpenAll: { showingAllLogs = true }
            )
        }
    }

    private var emptyLayoutState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No cards shown")
                .font(.headline)
            Text("All cards have been hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Edit Home") {
                withAnimation(.easeInOut(duration: DesignTokens.Duration.mediumAnimation)) {
                    layout.isEditing = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxl)
    }

    private func startPermitJoin(duration: Int, deviceName: String?, bridgeID: UUID?) {
        sendPermitJoin(duration: duration, deviceName: deviceName, bridgeID: bridgeID)
    }

    private func sendPermitJoin(duration: Int, deviceName: String?, bridgeID: UUID?) {
        var payload: [String: JSONValue] = ["time": .int(duration), "value": .bool(duration > 0)]
        if let deviceName, !deviceName.isEmpty {
            payload["device"] = .string(deviceName)
        }
        // Route to the user-selected bridge in multi-bridge mode; fall back to
        // the focused bridge when nothing's specified (single-bridge path).
        let store: AppStore
        if let bridgeID, let session = environment.registry.session(for: bridgeID) {
            environment.send(bridge: bridgeID, topic: Z2MTopics.Request.permitJoin, payload: .object(payload))
            store = session.store
        } else {
            environment.send(topic: Z2MTopics.Request.permitJoin, payload: .object(payload))
            store = environment.store
        }

        // Optimistically reflect the request in the targeted bridge's info so
        // the toolbar sheet / wizard / etc. update the moment the user taps,
        // without waiting for the bridge round-trip.
        if let info = store.bridgeInfo {
            store.bridgeInfo = info.copyUpdatingPermitJoin(
                enabled: duration > 0,
                timeout: duration > 0 ? duration : nil,
                target: duration > 0 ? deviceName : nil
            )
        }
    }
}

#Preview("Loaded") {
    HomeView()
        .environment(HomeView.previewEnvironment)
}

#Preview("Empty") {
    HomeView()
        .environment(AppEnvironment())
}

private extension HomeView {
    static var previewEnvironment: AppEnvironment {
        let environment = AppEnvironment()
        environment.store.isConnected = true
        environment.store.bridgeOnline = true
        environment.store.bridgeInfo = BridgeInfo(
            version: "2.9.2",
            commit: "2b485a98c5f9c879e1e9b80ffae3c7a84b0dce8d",
            coordinator: CoordinatorInfo(type: "EmberZNet", ieeeAddress: "0x4c5bb3fffe932a84", meta: nil),
            network: NetworkInfo(channel: 20, panID: 54_074, extendedPanID: nil),
            logLevel: "info",
            permitJoin: true,
            permitJoinTimeout: 48,
            permitJoinEnd: Int(Date().timeIntervalSince1970 * 1000) + 48_000,
            restartRequired: true,
            config: nil
        )
        environment.store.groups = [Group(id: 1, friendlyName: "Living Room", members: [], scenes: [])]
        environment.store.devices = [.preview, .fallbackPreview, Device(ieeeAddress: "0x003", type: .router, networkAddress: 3, supported: false, friendlyName: "Kitchen Relay", disabled: false, definition: nil, powerSource: "mains", interviewCompleted: false, interviewing: true)]
        environment.store.deviceAvailability = [Device.preview.friendlyName: true, Device.fallbackPreview.friendlyName: false, "Kitchen Relay": true]
        environment.store.deviceStates = [
            Device.preview.friendlyName: ["battery": .int(78), "linkquality": .int(128), "update": .object(["state": .string("available")])],
            Device.fallbackPreview.friendlyName: ["battery": .int(12), "linkquality": .int(28)],
            "Kitchen Relay": ["linkquality": .int(32)]
        ]
        return environment
    }
}
