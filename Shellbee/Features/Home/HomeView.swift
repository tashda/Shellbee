import SwiftUI

struct HomeView: View {
    var usesWideLayout: Bool = false

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @Environment(\.openURL) private var openURL

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
    // Optional cards, all off to begin with. Home answers "is anything
    // wrong" without any of them; these answer the questions you only ask
    // when you feel like looking. Switched on in Settings › Home.
    @AppStorage(HomeCardKind.network.storageKey) private var showsNetworkCard = false
    @AppStorage(HomeCardKind.linkQuality.storageKey) private var showsLinkQualityCard = false
    @AppStorage(HomeCardKind.batteries.storageKey) private var showsBatteriesCard = false
    @AppStorage(HomeCardKind.vendors.storageKey) private var showsVendorsCard = false
    @AppStorage(HomeCardKind.bridgeHealth.storageKey) private var showsBridgeHealthCard = false
    @AppStorage(HomeCardKind.activity.storageKey) private var showsActivityCard = false
    @State private var showingAllLogs = false
    @State private var showingStatistics = false

    /// One entry per saved bridge, including sessions that are reconnecting
    /// or offline, so Home can show their state. Each becomes a row.
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
            List {
                bridgeSection
                nowSection
                attentionSection
                optionalCards
                activitySection
            }
            .listStyle(.insetGrouped)
            .navigationDestination(isPresented: $showingStatistics) {
                if let bridgeID = selectedBridgeID {
                    DeviceStatisticsView(bridgeID: bridgeID)
                        .environment(environment)
                }
            }
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
            .task {
                await environment.releases.refresh()
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    OpenWindowMenu(currentDestination: .home)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PermitJoinToolbarButton(isActive: snapshot.isPermitJoinActive) {
                        isPermitJoinConfigPresented = true
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

    // MARK: - Sections
    //
    // Home answers two questions: is anything wrong, and what just
    // happened. Devices, Groups, Network Map and the Activity Center are
    // each a tab of their own, so anything they already own — counts,
    // routers, link quality, the channel — is not repeated here. What the
    // bridge itself reports lives in `BridgeInfoSheet`, one tap away.

    private var bridgeSection: some View {
        Section {
            ForEach(bridgeCardEntries) { entry in
                HomeBridgeRow(entry: entry) {
                    presentedSheet = .bridge(entry.id)
                }
                .modifier(BridgeRowLeadingBarBackground(bridgeID: entry.id, enabled: true))
            }
        }
    }

    // MARK: - Now
    //
    // The one card on Home, because it is the one thing here you operate.
    // It appears only while something is in flight and takes itself away
    // when that finishes.

    private var permitJoins: [HomeNowCard.PermitJoin] {
        let namesBridge = bridgeCardEntries.count >= 2
        return bridgeCardEntries.compactMap { entry in
            guard entry.isPermitJoinActive, let end = entry.permitJoinEnd else { return nil }
            let endsAt = Date(timeIntervalSince1970: Double(end) / 1_000)
            guard endsAt > Date() else { return nil }
            return HomeNowCard.PermitJoin(
                bridgeID: entry.id,
                bridgeName: entry.name,
                endsAt: endsAt,
                namesBridge: namesBridge
            )
        }
    }

    /// Mean progress across the devices actually flashing right now.
    private var updateProgress: Double? {
        let values = environment.registry.orderedSessions
            .flatMap { $0.store.otaUpdates.values }
            .filter { $0.phase == .updating }
            .compactMap(\.progress)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count) / 100
    }

    @ViewBuilder
    private var nowSection: some View {
        let joins = permitJoins
        if HomeNowCard.hasContent(
            permitJoins: joins,
            updatingCount: snapshot.updatingDevices,
            interviewingCount: snapshot.interviewingDevices
        ) {
            Section {
                HomeNowCard(
                    permitJoins: joins,
                    updatingCount: snapshot.updatingDevices,
                    updateProgress: updateProgress,
                    interviewingCount: snapshot.interviewingDevices,
                    onOpenUpdates: { showDevices(filter: .updatesAvailable) },
                    onStopPermitJoin: { stopPermitJoin(bridgeID: $0) }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var attentionItems: [HomeAttentionItem] {
        HomeAttentionItem.items(snapshot: snapshot)
    }

    /// Needs attention is device problems. Anything true of one bridge —
    /// a pending restart, a Zigbee2MQTT release — gets its own section
    /// headed with that bridge's name, so which bridge is never something
    /// you work out from a colour. With one bridge there is nothing to
    /// disambiguate, so it all reads as one section.
    @ViewBuilder
    private var attentionSection: some View {
        let entries = bridgeCardEntries
        let perBridge = entries.map { entry in
            (entry: entry, items: HomeAttentionItem.bridgeItems(
                for: entry,
                latestVersion: environment.releases.latestVersion
            ))
        }.filter { !$0.items.isEmpty }
        let deviceItems = attentionItems

        if entries.count <= 1 {
            let all = perBridge.flatMap(\.items) + deviceItems
            if !all.isEmpty {
                Section("Needs attention") {
                    ForEach(all) { attentionRow($0) }
                }
            }
        } else {
            ForEach(perBridge, id: \.entry.id) { group in
                Section("Needs attention · \(group.entry.name)") {
                    ForEach(group.items) { attentionRow($0) }
                }
            }
            if !deviceItems.isEmpty {
                Section(perBridge.isEmpty ? "Needs attention" : "Needs attention · All bridges") {
                    ForEach(deviceItems) { attentionRow($0) }
                }
            }
        }
    }

    private func attentionRow(_ item: HomeAttentionItem) -> some View {
        Button { perform(item.action) } label: {
            HomeAttentionRow(item: item)
        }
        .buttonStyle(.plain)
    }

    private func perform(_ action: HomeAttentionItem.Action) {
        switch action {
        case .devices(let filter):
            showDevices(filter: filter)
        case .restart(let bridgeID):
            pendingRestartBridgeID = bridgeID
            showingRestartAlert = true
        case .release(let url):
            openURL(url)
        }
    }

    // MARK: - Optional cards

    @ViewBuilder
    private var optionalCards: some View {
        if showsNetworkCard {
            cardSection {
                HomeNetworkCard(snapshot: snapshot) {
                    sceneNavigation.selectedTab = .networkMap
                }
            }
        }
        if showsLinkQualityCard {
            cardSection {
                HomeLinkQualityCard(snapshot: snapshot) {
                    showDevices(filter: .weakSignal)
                }
            }
        }
        if showsBatteriesCard {
            cardSection {
                HomeBatteriesCard(snapshot: snapshot) {
                    showDevices(filter: .batteryLow)
                }
            }
        }
        if showsVendorsCard {
            cardSection {
                // Merged across bridges, like every other card here. The
                // statistics screen it opens is per-bridge by design, so it
                // opens on the selected one.
                HomeVendorsCard(devices: environment.allDevices.map(\.device)) {
                    showingStatistics = true
                }
            }
        }
        if showsBridgeHealthCard {
            ForEach(bridgeCardEntries) { entry in
                cardSection {
                    HomeBridgeHealthCard(
                        entry: entry,
                        namesBridge: bridgeCardEntries.count >= 2
                    ) {
                        presentedSheet = .bridge(entry.id)
                    }
                }
            }
        }
    }

    /// A card sits in its own section so the List draws no row chrome
    /// around it — the card is the surface.
    private func cardSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Section {
            content()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if showsActivityCard {
            let items = recentEventItems(for: nil)
            Section("Activity") {
                if items.isEmpty {
                    Text("No recent events")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        Button {
                            sceneNavigation.pendingLogSheet = LogSheetRequest(entryIDs: [item.id])
                        } label: {
                            HomeActivityRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    Button("See all", action: openAllLogs)
                }
            }
        }
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
    case bridge(UUID)

    var id: String {
        switch self {
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
