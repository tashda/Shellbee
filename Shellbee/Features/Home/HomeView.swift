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
    @AppStorage(HomeCardKind.network.storageKey) private var showsNetworkCard = HomeCardKind.network.isOnByDefault
    @AppStorage(HomeCardKind.linkQuality.storageKey) private var showsLinkQualityCard = HomeCardKind.linkQuality.isOnByDefault
    @AppStorage(HomeCardKind.batteries.storageKey) private var showsBatteriesCard = HomeCardKind.batteries.isOnByDefault
    @AppStorage(HomeCardKind.vendors.storageKey) private var showsVendorsCard = HomeCardKind.vendors.isOnByDefault
    @AppStorage(HomeCardKind.bridgeHealth.storageKey) private var showsBridgeHealthCard = HomeCardKind.bridgeHealth.isOnByDefault
    @AppStorage(HomeCardKind.activity.storageKey) private var showsActivityCard = HomeCardKind.activity.isOnByDefault
    @AppStorage(HomeCardKind.orderKey) private var cardOrder = ""
    @State private var showingAllLogs = false
    @State private var showingStatistics = false
    @State private var showingLinkQuality = false
    @State private var showingBatteries = false
    @State private var batterySheet: HomeDeviceReading?
    @State private var openedDevice: DeviceRoute?
    @State private var pendingStopPermitJoin: UUID?
    @State private var showingStopUpdateCheck = false

    private var bridgeCardEntries: [HomeBridgeCardEntry] {
        environment.homeBridgeCardEntries(selectedBridgeID: selectedBridgeID)
    }

    private func makeDeviceReadings() -> [HomeDeviceReading] {
        environment.homeDeviceReadings(selectedBridgeID: selectedBridgeID)
    }

    private var isLoadingDevices: Bool {
        environment.allDevices.isEmpty && environment.isLoading(.devices)
    }

    private func makeSnapshot() -> HomeSnapshot {
        environment.homeSnapshot(selectedBridgeID: selectedBridgeID)
    }

    var body: some View {
        // Built once per redraw and passed down: each walks every device,
        // and Home redraws on every message from the bridge.
        let snapshot = makeSnapshot()
        let shownCards = shownCards
        let needsReadings = shownCards.contains(.linkQuality) || shownCards.contains(.batteries)
            || showingLinkQuality || showingBatteries
        let deviceReadings = needsReadings ? makeDeviceReadings() : []
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
                bridgeSection
                nowSection(snapshot)
                if isLoadingDevices {
                    // Cards drawn from placeholder data until the bridge's
                    // devices arrive, instead of zeros and empty lists.
                    ForEach(shownCards) { card($0, snapshot: snapshot, readings: deviceReadings) }
                        .redacted(reason: .placeholder)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else {
                    attentionSection(snapshot)
                    ForEach(shownCards) { card($0, snapshot: snapshot, readings: deviceReadings) }
                }
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: DesignTokens.Size.readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await environment.refreshBridgeData(bridgeID: nil) }
            .shellbeeThemedCanvas(fallback: Color(.systemGroupedBackground))
            .navigationDestination(isPresented: $showingStatistics) {
                if let bridgeID = selectedBridgeID {
                    DeviceStatisticsView(bridgeID: bridgeID, defaultsToAllBridges: true)
                        .environment(environment)
                }
            }
            .navigationDestination(isPresented: $showingLinkQuality) {
                LinkQualityPage(readings: deviceReadings)
            }
            .navigationDestination(isPresented: $showingBatteries) {
                BatteriesPage(readings: deviceReadings)
            }
            .navigationDestination(for: DeviceRoute.self) { route in
                DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
            }
            .navigationDestination(item: $openedDevice) { route in
                DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
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
            .sheet(item: $batterySheet) { reading in
                BatteryQuickSheet(reading: reading) { openedDevice = $0 }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .bridge(let bridgeID):
                    BridgeInfoSheet(bridgeID: bridgeID)
                        .environment(environment)
                }
            }
            .alert("Stop Pairing?", isPresented: Binding(
                get: { pendingStopPermitJoin != nil },
                set: { if !$0 { pendingStopPermitJoin = nil } }
            )) {
                Button("Stop Pairing", role: .destructive) {
                    stopPermitJoin(bridgeID: pendingStopPermitJoin)
                    pendingStopPermitJoin = nil
                }
                Button("Cancel", role: .cancel) { pendingStopPermitJoin = nil }
            } message: {
                Text("New devices can't join until you open pairing again.")
            }
            .alert("Stop Checking for Updates?", isPresented: $showingStopUpdateCheck) {
                Button("Stop Checking", role: .destructive) { environment.cancelOTAChecks() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Devices already checked keep their result. The rest aren't checked.")
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
        groupedRows {
            ForEach(Array(bridgeCardEntries.enumerated()), id: \.element.id) { index, entry in
                groupedRow(HomeBridgeRow(entry: entry) {
                    presentedSheet = .bridge(entry.id)
                })
                if index < bridgeCardEntries.count - 1 {
                    Divider().padding(.leading, DesignTokens.Spacing.lg)
                }
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
    private func nowSection(_ snapshot: HomeSnapshot) -> some View {
        let joins = permitJoins
        let updateCheck = environment.otaCheckProgress
        if HomeNowCard.hasContent(
            permitJoins: joins,
            updatingCount: snapshot.updatingDevices,
            interviewingCount: snapshot.interviewingDevices,
            updateCheck: updateCheck
        ) {
            HomeNowCard(
                permitJoins: joins,
                updatingCount: snapshot.updatingDevices,
                updateProgress: updateProgress,
                interviewingCount: snapshot.interviewingDevices,
                updateCheck: updateCheck,
                onOpenUpdates: { showDevices(filter: .updatesAvailable) },
                onStopPermitJoin: { pendingStopPermitJoin = $0 },
                onStopUpdateCheck: { showingStopUpdateCheck = true }
            )
        }
    }

    /// Needs attention is device problems. Anything true of one bridge —
    /// a pending restart, a Zigbee2MQTT release — gets its own section
    /// headed with that bridge's name, so which bridge is never something
    /// you work out from a colour. With one bridge there is nothing to
    /// disambiguate, so it all reads as one section.
    @ViewBuilder
    private func attentionSection(_ snapshot: HomeSnapshot) -> some View {
        let entries = bridgeCardEntries
        let perBridge = entries.map { entry in
            (entry: entry, items: HomeAttentionItem.bridgeItems(
                for: entry,
                latestVersion: environment.releases.latestVersion
            ))
        }.filter { !$0.items.isEmpty }
        let deviceItems = HomeAttentionItem.items(snapshot: snapshot)

        if entries.count <= 1 {
            let all = perBridge.flatMap(\.items) + deviceItems
            if !all.isEmpty {
                groupedRows(title: "Needs attention") {
                    ForEach(Array(all.enumerated()), id: \.element.id) { index, item in
                        groupedRow(attentionRow(item))
                        if index < all.count - 1 { Divider().padding(.leading, DesignTokens.Spacing.lg) }
                    }
                }
            }
        } else {
            ForEach(perBridge, id: \.entry.id) { group in
                groupedRows(title: "Needs attention · \(group.entry.name)") {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        groupedRow(attentionRow(item))
                        if index < group.items.count - 1 { Divider().padding(.leading, DesignTokens.Spacing.lg) }
                    }
                }
            }
            if !deviceItems.isEmpty {
                groupedRows(title: perBridge.isEmpty ? "Needs attention" : "Needs attention · All bridges") {
                    ForEach(Array(deviceItems.enumerated()), id: \.element.id) { index, item in
                        groupedRow(attentionRow(item))
                        if index < deviceItems.count - 1 { Divider().padding(.leading, DesignTokens.Spacing.lg) }
                    }
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

    private var shownCards: [HomeCardKind] {
        HomeCardKind.ordered(cardOrder).filter { kind in
            switch kind {
            case .network: showsNetworkCard
            case .linkQuality: showsLinkQualityCard
            case .batteries: showsBatteriesCard
            case .vendors: showsVendorsCard
            case .bridgeHealth: showsBridgeHealthCard && !bridgeCardEntries.isEmpty
            case .activity: showsActivityCard
            }
        }
    }

    @ViewBuilder
    private func card(_ kind: HomeCardKind, snapshot: HomeSnapshot, readings deviceReadings: [HomeDeviceReading]) -> some View {
        switch kind {
        case .network:
            HomeNetworkCard(snapshot: snapshot) {
                sceneNavigation.selectedTab = .networkMap
            } onOpenStatistics: {
                showingStatistics = true
            }
        case .linkQuality:
            HomeLinkQualityCard(
                snapshot: snapshot,
                readings: deviceReadings,
                onTapWeak: { showDevices(filter: .weakSignal) },
                onOpenPage: { showingLinkQuality = true }
            )
        case .batteries:
            HomeBatteriesCard(
                snapshot: snapshot,
                readings: deviceReadings,
                onSelect: { batterySheet = $0 },
                onOpenPage: { showingBatteries = true }
            )
        case .vendors:
            HomeVendorsCard(devices: environment.allDevices.map(\.device))
        case .bridgeHealth:
            if bridgeCardEntries.count >= 2 {
                HomeBridgeHealthGroupCard(entries: bridgeCardEntries) { bridgeID in
                    presentedSheet = .bridge(bridgeID)
                }
            } else if let entry = bridgeCardEntries.first {
                HomeBridgeHealthCard(entry: entry) {
                    presentedSheet = .bridge(entry.id)
                }
            }
        case .activity:
            activitySection
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        let items = recentEventItems(for: nil)
        groupedRows(title: "Activity") {
            if items.isEmpty {
                groupedRow(Text("No recent events")
                    .foregroundStyle(.secondary)
                )
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    groupedRow(Button {
                        sceneNavigation.pendingLogSheet = LogSheetRequest(entryIDs: [item.id])
                    } label: {
                        HomeActivityRow(item: item)
                    }.buttonStyle(.plain))
                    if index < items.count - 1 { Divider().padding(.leading, DesignTokens.Spacing.lg) }
                }
                Divider().padding(.leading, DesignTokens.Spacing.lg)
                groupedRow(Button("See all", action: openAllLogs))
            }
        }
    }

    private func groupedRows<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DesignTokens.Spacing.lg)
            }
            VStack(spacing: 0, content: content)
                .background(
                    .shellbeeSurface,
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        }
    }

    private func groupedRow<Content: View>(_ content: Content) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.homeRowMinHeight, alignment: .leading)
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
