import SwiftUI

struct HomeView: View {
    var usesWideLayout: Bool = false

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation

    @State private var isPermitJoinConfigPresented = false
    @State private var showingRestartAlert = false
    @State private var pendingRestartBridgeID: UUID?
    @State private var presentedSheet: HomeSheet?

    /// Phase 2 multi-bridge: every Home read goes through `selectedScope` —
    /// the user-selected bridge in the picker. Nil only when no bridge is
    /// connected; views guard accordingly. Permit Join, Restart, and the
    /// merged Recent Events log do their own per-bridge resolution.
    private var selectedScope: BridgeScope? {
        selectedBridgeID.map { environment.scope(for: $0) }
    }

    private var selectedBridgeID: UUID? {
        if let selected = sceneNavigation.selectedBridgeID,
           environment.registry.session(for: selected) != nil {
            return selected
        }
        return environment.registry.primaryBridgeID
            ?? environment.registry.orderedSessions.first?.bridgeID
    }

    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount: Int = HomeSettings.recentEventsCountDefault
    @AppStorage(HomeSettings.cardDisplayKey(.bridge)) private var bridgeCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.devices)) private var devicesCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.groups)) private var groupsCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.mesh)) private var meshCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.recentEvents)) private var recentEventsCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @State private var showingAllLogs = false
    @State private var layout = HomeLayoutStore()

    /// Per-bridge entries for the Home Bridge card. Always includes every
    /// session — even ones that are reconnecting or offline — so the card can
    /// surface their status. In single-bridge mode this is just one entry, and
    /// the card renders the legacy layout.
    private var bridgeCardEntries: [HomeBridgeCardEntry] {
        let primaryID = selectedBridgeID
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

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    private var homeCards: [HomeCardInstance] {
        layout.visibleOrder.flatMap { type in
            let sessions = type == .bridge
                ? bridgeCardEntries.map(\.id)
                : connectedSessions.map(\.bridgeID)
            guard displayMode(for: type) == .perBridge, sessions.count >= 2 else {
                return [HomeCardInstance(type: type)]
            }
            return sessions.map { HomeCardInstance(type: type, bridgeID: $0) }
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
            let primary = selectedBridgeID.flatMap { environment.registry.session(for: $0) }

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

        // Single-bridge / no-bridge path: read from the user's selected bridge
        // when present, otherwise present an empty snapshot so HomeView still
        // renders during cold start.
        guard let scope = selectedScope else {
            return HomeSnapshot(
                devices: [], availability: [:], states: [:],
                isConnected: false, isBridgeOnline: false, groupCount: 0,
                bridgeVersion: nil, bridgeCommit: nil,
                coordinatorType: nil, coordinatorIEEEAddress: nil,
                networkChannel: nil, panID: nil,
                isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
            )
        }
        let store = scope.store
        return HomeSnapshot(
            devices: store.devices,
            availability: store.deviceAvailability,
            states: store.deviceStates,
            otaStatuses: store.otaUpdates,
            isConnected: store.isConnected,
            isBridgeOnline: store.bridgeOnline,
            groupCount: store.groups.count,
            bridgeVersion: store.bridgeInfo?.version,
            bridgeCommit: store.bridgeInfo?.commit,
            coordinatorType: store.bridgeInfo?.coordinator.type,
            coordinatorIEEEAddress: store.bridgeInfo?.coordinator.ieeeAddress,
            networkChannel: store.bridgeInfo?.network?.channel,
            panID: store.bridgeInfo?.network?.panID,
            isPermitJoinActive: store.bridgeInfo?.permitJoin ?? false,
            permitJoinEnd: store.bridgeInfo?.permitJoinEnd,
            restartRequired: store.bridgeInfo?.restartRequired ?? false
        )
    }

    var body: some View {
        NavigationStack {
            HomeCardsCollection(
                layout: layout,
                usesWideLayout: usesWideLayout,
                cards: homeCards
            ) { card in
                cardView(for: card)
            } emptyContent: {
                emptyLayoutState
            }
            .background(HomeBackgroundGradient().ignoresSafeArea())
            .navigationDestination(isPresented: $showingAllLogs) {
                LogsView(usesActivityFeed: true, navigationTitle: "Activity")
            }
            .task(id: selectedScope?.store.isConnected ?? false) {
                // Phase 2 multi-bridge: probe health on every connected bridge
                // when the selected bridge transitions to connected. The
                // health card aggregates per-bridge.
                for session in environment.registry.orderedSessions where session.isConnected {
                    environment.send(bridge: session.bridgeID, topic: Z2MTopics.Request.healthCheck, payload: .object([:]))
                }
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
                        OpenWindowMenu(currentDestination: .home)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        PermitJoinToolbarButton(isActive: snapshot.isPermitJoinActive) {
                            isPermitJoinConfigPresented = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isPermitJoinConfigPresented) {
                PermitJoinSheet(
                    onStart: startPermitJoin,
                    onStop: stopPermitJoin
                )
                .environment(environment)
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .mesh(let bridgeID):
                    MeshDetailView(snapshot: snapshot(for: bridgeID))
                        .environment(environment)
                case .bridge(let bridgeID):
                    BridgeInfoSheet(bridgeID: bridgeID)
                        .environment(environment)
                }
            }
            .alert("Restart Bridge?", isPresented: $showingRestartAlert) {
                Button("Restart", role: .destructive) {
                    let id = pendingRestartBridgeID ?? selectedBridgeID
                    if let id { environment.restartBridge(id) }
                    pendingRestartBridgeID = nil
                }
                Button("Cancel", role: .cancel) { pendingRestartBridgeID = nil }
            } message: {
                Text("Restarting the bridge will apply pending configuration changes and temporarily disconnect all Zigbee devices.")
            }
        }
        .configuredTopScrollEdgeEffect()
    }

    @ViewBuilder
    private func cardView(for card: HomeCardInstance) -> some View {
        switch card.type {
        case .bridge:
            HomeBridgeCard(
                entries: bridgeEntries(for: card),
                onRestart: { id in
                    pendingRestartBridgeID = id
                    showingRestartAlert = true
                },
                onOpenBridge: { id in
                    presentedSheet = .bridge(id)
                }
            )
        case .devices:
            HomeDevicesCard(snapshot: snapshot(for: card.bridgeID), bridgeName: bridgeName(for: card.bridgeID)) {
                showDevices(filter: .all, bridgeID: card.bridgeID)
            } onFilter: {
                showDevices(filter: $0, bridgeID: card.bridgeID)
            }
        case .groups:
            HomeGroupsCard(
                count: card.bridgeID.flatMap { environment.registry.session(for: $0)?.store.groups.count }
                    ?? environment.allGroups.count,
                bridgeName: bridgeName(for: card.bridgeID)
            ) {
                if let bridgeID = card.bridgeID {
                    sceneNavigation.selectedBridgeID = bridgeID
                }
                sceneNavigation.selectedTab = .groups
            }
        case .mesh:
            HomeMeshCard(snapshot: snapshot(for: card.bridgeID), bridgeName: bridgeName(for: card.bridgeID)) {
                presentedSheet = .mesh(card.bridgeID)
            } onFilter: {
                showDevices(filter: $0, bridgeID: card.bridgeID)
            }
        case .recentEvents:
            // Phase 2 multi-bridge: merge the most-recent events across every
            // bridge so the card shows the user's whole network. LQI-only
            // drift is suppressed here for the same reason it's hidden in
            // the Activity Log by default — it's noise, not events the
            // user wants on their home screen.
            HomeLogsCard(
                items: recentEventItems(for: card.bridgeID),
                showsExpandedDetails: usesWideLayout,
                bridgeName: bridgeName(for: card.bridgeID),
                onOpenItem: { item in
                    sceneNavigation.pendingLogSheet = LogSheetRequest(entryIDs: [item.id])
                },
                onOpenAll: openAllLogs
            )
        }
    }

    private func displayMode(for type: HomeCardID) -> HomeCardDisplayMode {
        let raw: String
        switch type {
        case .bridge: raw = bridgeCardDisplayRaw
        case .devices: raw = devicesCardDisplayRaw
        case .groups: raw = groupsCardDisplayRaw
        case .mesh: raw = meshCardDisplayRaw
        case .recentEvents: raw = recentEventsCardDisplayRaw
        }
        return HomeCardDisplayMode(rawValue: raw) ?? .one
    }

    private func bridgeEntries(for card: HomeCardInstance) -> [HomeBridgeCardEntry] {
        guard let bridgeID = card.bridgeID else { return bridgeCardEntries }
        return bridgeCardEntries.filter { $0.id == bridgeID }
    }

    private func bridgeName(for bridgeID: UUID?) -> String? {
        bridgeID.flatMap { environment.registry.session(for: $0)?.displayName }
    }

    private func snapshot(for bridgeID: UUID?) -> HomeSnapshot {
        guard let bridgeID,
              let session = environment.registry.session(for: bridgeID)
        else { return snapshot }

        let store = session.store
        return HomeSnapshot(
            devices: store.devices,
            availability: store.deviceAvailability,
            states: store.deviceStates,
            otaStatuses: store.otaUpdates,
            isConnected: store.isConnected,
            isBridgeOnline: store.bridgeOnline,
            groupCount: store.groups.count,
            bridgeVersion: store.bridgeInfo?.version,
            bridgeCommit: store.bridgeInfo?.commit,
            coordinatorType: store.bridgeInfo?.coordinator.type,
            coordinatorIEEEAddress: store.bridgeInfo?.coordinator.ieeeAddress,
            networkChannel: store.bridgeInfo?.network?.channel,
            panID: store.bridgeInfo?.network?.panID,
            isPermitJoinActive: store.bridgeInfo?.permitJoin ?? false,
            permitJoinEnd: store.bridgeInfo?.permitJoinEnd,
            restartRequired: store.bridgeInfo?.restartRequired ?? false
        )
    }

    private func recentEventItems(for bridgeID: UUID?) -> [ActivityEventItem] {
        let limit = usesWideLayout
            ? max(recentEventsCount, HomeSettings.wideRecentEventsMinimum)
            : recentEventsCount
        let entries: [BridgeBoundLogEntry]
        if let bridgeID, let session = environment.registry.session(for: bridgeID) {
            entries = Array(session.store.logEntries
                .lazy
                .filter { !LogRowIconography.isLinkQualityOnly($0) }
                .prefix(limit)
                .map { BridgeBoundLogEntry(bridgeID: bridgeID, bridgeName: session.displayName, entry: $0) })
        } else {
            entries = Array(environment.allLogEntries
                .lazy
                .filter { !LogRowIconography.isLinkQualityOnly($0.entry) }
                .prefix(limit))
        }
        return entries.map(environment.activityEventItem(for:))
    }

    private func showDevices(filter: DeviceQuickFilter, bridgeID: UUID? = nil) {
        sceneNavigation.pendingDeviceBridgeID = bridgeID
        sceneNavigation.pendingDeviceFilter = filter
        sceneNavigation.selectedTab = .devices
    }

    private func openAllLogs() {
        if AdaptiveLayout.isPad {
            sceneNavigation.selectedTab = .logs
        } else {
            showingAllLogs = true
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
        // Phase 2 multi-bridge: PermitJoinSheet always provides a `bridgeID`
        // when ≥2 bridges are connected. Single-bridge mode passes nil and we
        // resolve to the only connected session.
        let id = bridgeID ?? selectedBridgeID
        guard let id else { return }
        sendPermitJoin(duration: duration, deviceName: deviceName, bridgeID: id)
    }

    private func stopPermitJoin(bridgeID: UUID?) {
        let id = bridgeID ?? selectedBridgeID
        guard let id else { return }
        sendPermitJoin(duration: 0, deviceName: nil, bridgeID: id)
    }

    private func sendPermitJoin(duration: Int, deviceName: String?, bridgeID: UUID) {
        guard let session = environment.registry.session(for: bridgeID) else { return }
        var payload: [String: JSONValue] = ["time": .int(duration), "value": .bool(duration > 0)]
        if let deviceName, !deviceName.isEmpty {
            payload["device"] = .string(deviceName)
        }
        environment.send(bridge: bridgeID, topic: Z2MTopics.Request.permitJoin, payload: .object(payload))

        // Optimistically reflect the request in the targeted bridge's info so
        // the toolbar sheet / wizard / etc. update the moment the user taps,
        // without waiting for the bridge round-trip.
        if let info = session.store.bridgeInfo {
            session.store.bridgeInfo = info.copyUpdatingPermitJoin(
                enabled: duration > 0,
                timeout: duration > 0 ? duration : nil,
                target: duration > 0 ? deviceName : nil
            )
        }
    }
}

private enum HomeSheet: Identifiable {
    case mesh(UUID?)
    case bridge(UUID)

    var id: String {
        switch self {
        case .mesh(let bridgeID): "mesh-\(bridgeID?.uuidString ?? "all")"
        case .bridge(let bridgeID): "bridge-\(bridgeID.uuidString)"
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
    /// Phase 3 multi-bridge: previews construct a real `BridgeSession` via
    /// `connect(config:)` so the preview is exercising the same canonical
    /// path production code uses. The session's WebSocket attempt fails in
    /// the preview sandbox, but the store is live and we populate it
    /// directly to render representative data.
    @MainActor
    static var previewEnvironment: AppEnvironment {
        let environment = AppEnvironment()
        let config = ConnectionConfig(
            id: UUID(),
            host: "preview.local", port: 8080, useTLS: false, basePath: "/",
            authToken: nil, name: "Preview Bridge"
        )
        environment.connect(config: config)
        guard let store = environment.registry.session(for: config.id)?.store else {
            return environment
        }
        store.isConnected = true
        store.bridgeOnline = true
        store.bridgeInfo = BridgeInfo(
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
        store.groups = [Group(id: 1, friendlyName: "Living Room", members: [], scenes: [])]
        store.devices = [.preview, .fallbackPreview, Device(ieeeAddress: "0x003", type: .router, networkAddress: 3, supported: false, friendlyName: "Kitchen Relay", disabled: false, definition: nil, powerSource: "mains", interviewCompleted: false, interviewing: true)]
        store.deviceAvailability = [Device.preview.friendlyName: true, Device.fallbackPreview.friendlyName: false, "Kitchen Relay": true]
        store.deviceStates = [
            Device.preview.friendlyName: ["battery": .int(78), "linkquality": .int(128), "update": .object(["state": .string("available")])],
            Device.fallbackPreview.friendlyName: ["battery": .int(12), "linkquality": .int(28)],
            "Kitchen Relay": ["linkquality": .int(32)]
        ]
        return environment
    }
}
