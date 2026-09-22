import SwiftUI

/// The plumbing, as one card: the bridge's connection state, how much of the
/// network answered, and the mesh's shape. Replaces the separate Bridge and
/// Mesh cards — they were the same subject told twice.
///
/// The hero is the connection state, because that is the only question this
/// card exists to answer. Uptime and message counters are receipts: they sit
/// in a caption-sized footer, and during an outage they dim and carry the time
/// they were last true, so a stale counter can't be read as a live one.
struct HomeNetworkCard: View {
    let entries: [HomeBridgeCardEntry]
    let snapshot: HomeSnapshot
    /// When the focused bridge's health last arrived. Timestamps stale stats.
    let healthUpdatedAt: Date?
    let onRestart: (UUID) -> Void
    let onTap: () -> Void
    let onFilter: (DeviceQuickFilter) -> Void
    var onSelectBridge: ((UUID) -> Void)? = nil

    /// Latest Z2M version from GitHub Releases. Polled at most every 5 min,
    /// shared by every bridge row so we don't fan out the same network call.
    @State private var latestVersion: String? = nil
    @State private var lastVersionFetch: Date? = nil

    var body: some View {
        SwiftUI.Group {
            if entries.count >= 2 {
                multiBridgeCard
            } else {
                HomeNetworkCardSingle(
                    entry: entries.first,
                    snapshot: snapshot,
                    latestVersion: latestVersion,
                    healthUpdatedAt: healthUpdatedAt,
                    onRestart: onRestart,
                    onFilter: onFilter
                )
                .contentShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
                .gesture(TapGesture().onEnded(onTap), including: .gesture)
            }
        }
        .task(id: entries.compactMap(\.version).joined(separator: ",")) {
            await fetchLatestVersion()
        }
    }

    private var multiBridgeCard: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HomeCardTitle(symbol: "antenna.radiowaves.left.and.right", title: "Network", tint: .teal)
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        HomeBridgeCardRow(
                            entry: entry,
                            latestVersion: latestVersion,
                            onRestart: { onRestart(entry.id) },
                            onSelect: onSelectBridge.map { handler in { handler(entry.id) } }
                        )
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
                Divider()
                HomeMeshStats(snapshot: snapshot, onFilter: onFilter)
            }
        }
    }

    private func fetchLatestVersion() async {
        if let last = lastVersionFetch, Date().timeIntervalSince(last) < 300 { return }
        guard let url = URL(string: "https://api.github.com/repos/Koenkk/zigbee2mqtt/releases/latest") else { return }
        lastVersionFetch = Date()
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        struct Release: Decodable { let tag_name: String }
        guard let release = try? JSONDecoder().decode(Release.self, from: data) else { return }
        latestVersion = release.tag_name
    }
}

// MARK: - Mesh

/// The mesh's shape, shared by the single- and multi-bridge layouts.
private struct HomeMeshStats: View {
    let snapshot: HomeSnapshot
    let onFilter: (DeviceQuickFilter) -> Void

    var body: some View {
        HomeStatRow {
            Button { onFilter(.router) } label: {
                HomeStatCell(label: "Routers", value: "\(snapshot.routerCount)", count: snapshot.routerCount)
            }
            .buttonStyle(StatCellButtonStyle())

            Button { onFilter(.endDevice) } label: {
                HomeStatCell(label: "End devices", value: "\(snapshot.endDeviceCount)", count: snapshot.endDeviceCount)
            }
            .buttonStyle(StatCellButtonStyle())

            if let lqi = snapshot.averageLinkQuality {
                HomeStatCell(
                    label: "Avg LQI",
                    value: "\(lqi)",
                    valueColor: lqi >= DesignTokens.Threshold.weakSignal ? .primary : .red,
                    count: lqi
                )
            }
        }
    }
}

// MARK: - Single bridge

private struct HomeNetworkCardSingle: View {
    let entry: HomeBridgeCardEntry?
    let snapshot: HomeSnapshot
    let latestVersion: String?
    let healthUpdatedAt: Date?
    let onRestart: (UUID) -> Void
    let onFilter: (DeviceQuickFilter) -> Void

    private var headerTitle: String {
        guard let name = entry?.name, !name.isEmpty else { return "Network" }
        return name
    }

    private var updateAvailable: Bool {
        guard let latest = latestVersion.flatMap(Z2MVersion.parse),
              let current = entry?.version.flatMap(Z2MVersion.parse) else { return false }
        return latest > current
    }

    private var hasMemoryAlert: Bool {
        let z2mHigh = (entry?.health?.process?.memoryPercent ?? 0) > 30
        let osHigh = (entry?.health?.os?.memoryPercent ?? 0) > 85
        return z2mHigh || osHigh
    }

    private var mqttDown: Bool {
        if let connected = entry?.health?.mqtt?.connected { return !connected }
        return false
    }

    private var isDegraded: Bool {
        entry?.isWebSocketConnected != true || entry?.isBridgeOnline != true || mqttDown
    }

    /// Permit join and interviews live on the pinned "right now" card, not
    /// here: this card is the steady state.
    private var hasActions: Bool {
        updateAvailable || entry?.restartRequired == true || hasMemoryAlert
    }

    /// A calm card collapses to one line. Trouble here is never only about the
    /// bridge: a mesh full of unreachable devices keeps the card open too.
    private var isCalm: Bool {
        snapshot.networkIsCalm && !isDegraded && !hasActions && snapshot.offlineDevices == 0
    }

    var body: some View {
        if isCalm {
            HomeCardContainer(padding: DesignTokens.Spacing.md) {
                HomeCalmSummary(
                    symbol: "antenna.radiowaves.left.and.right",
                    title: headerTitle,
                    tint: .teal,
                    detail: calmDetail
                )
            }
        } else {
            HomeCardContainer {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    header
                    statusHero
                    if snapshot.totalDevices > 0 {
                        reachability
                    }
                    HomeMeshStats(snapshot: snapshot, onFilter: onFilter)
                    if entry?.health != nil {
                        footerStats
                    }
                    if hasActions {
                        HomeCardAlertList { actionRows }
                    }
                }
            }
        }
    }

    private var calmDetail: String {
        var parts: [String] = ["Healthy"]
        if let uptime = entry?.health?.process?.uptimeFormatted { parts.append("up \(uptime)") }
        if snapshot.devicesWithUpdates > 0 {
            parts.append("\(snapshot.devicesWithUpdates) update\(snapshot.devicesWithUpdates == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            HomeCardTitle(symbol: "antenna.radiowaves.left.and.right", title: headerTitle, tint: .teal)
                .lineLimit(1)
            Spacer(minLength: DesignTokens.Spacing.sm)
            if let host = entry?.subtitleHost {
                Text(host)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var statusHero: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HomeStatusDot(color: statusColor, isPulsing: entry?.isReconnecting == true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(statusTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isDegraded ? statusColor : .primary)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusColor: Color {
        if entry?.isWebSocketConnected != true { return .red }
        if entry?.isBridgeOnline != true || mqttDown { return .orange }
        return .green
    }

    private var statusTitle: String {
        if entry == nil { return "Not connected" }
        if entry?.isReconnecting == true { return "Reconnecting" }
        if entry?.isWebSocketConnected != true { return "Disconnected" }
        if entry?.isBridgeOnline != true { return "Bridge offline" }
        if mqttDown { return "MQTT disconnected" }
        return "Connected"
    }

    private var statusDetail: String {
        guard let entry else { return "Add a bridge to get started" }
        if entry.isReconnecting {
            return "Attempt \(entry.reconnectAttempt)"
        }
        var parts: [String] = []
        if let version = entry.version { parts.append("Zigbee2MQTT \(version)") }
        if let uptime = entry.health?.process?.uptimeFormatted { parts.append("up \(uptime)") }
        return parts.isEmpty ? "Connected to \(entry.host)" : parts.joined(separator: " · ")
    }

    private var reachability: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HomeReachabilityBar(
                online: snapshot.onlineDevices,
                offline: snapshot.offlineDevices,
                untracked: snapshot.availabilityOffDevices
            )
            Text(reachabilityCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var reachabilityCaption: String {
        var parts = ["\(snapshot.onlineDevices) answering"]
        if snapshot.offlineDevices > 0 { parts.append("\(snapshot.offlineDevices) offline") }
        if snapshot.availabilityOffDevices > 0 { parts.append("\(snapshot.availabilityOffDevices) untracked") }
        return parts.joined(separator: " · ")
    }

    /// Receipts. Dimmed and timestamped while the bridge is unreachable — the
    /// numbers were true once, and saying when is more useful than hiding them.
    private var footerStats: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Divider()
            HStack(spacing: DesignTokens.Spacing.md) {
                if let published = entry?.health?.mqtt?.published {
                    Text("\(formatCount(published)) published")
                }
                if let received = entry?.health?.mqtt?.received {
                    Text("\(formatCount(received)) received")
                }
                if let response = entry?.health?.responseTime {
                    Text("\(response) ms")
                }
                if isDegraded, let asOf = healthUpdatedAt {
                    Text("as of \(asOf, format: .dateTime.hour().minute())")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .opacity(isDegraded ? DesignTokens.Opacity.staleStats : 1)
        }
    }

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 0..<1_000: return "\(n)"
        case 1_000..<1_000_000: return String(format: "%.0fK", Double(n) / 1_000)
        default: return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }

    @ViewBuilder
    private var actionRows: some View {
        if updateAvailable, let latest = latestVersion,
           let url = URL(string: "https://github.com/Koenkk/zigbee2mqtt/releases/tag/\(latest)") {
            Link(destination: url) {
                HomeCardAlertRow(symbol: "arrow.down.circle.fill", title: "v\(latest) available", color: .blue, action: nil)
            }
            .foregroundStyle(.primary)
        }
        if entry?.restartRequired == true, let id = entry?.id {
            HomeCardAlertRow(
                symbol: "arrow.triangle.2.circlepath.circle.fill",
                title: "Restart required to apply configuration",
                color: .orange,
                action: { onRestart(id) }
            )
        }
        if let pct = entry?.health?.process?.memoryPercent, pct > 30 {
            HomeCardAlertRow(symbol: "memorychip", title: "High Z2M memory (\(Int(pct))%)", color: .orange, action: nil)
        }
        if let pct = entry?.health?.os?.memoryPercent, pct > 85 {
            HomeCardAlertRow(symbol: "memorychip", title: "High system memory (\(Int(pct))%)", color: .orange, action: nil)
        }
    }
}

#Preview("Trouble") {
    HomeNetworkCard(
        entries: [HomeNetworkCard.previewEntry(focused: true, reconnecting: 1)],
        snapshot: HomeNetworkCard.previewSnapshot(offline: 7),
        healthUpdatedAt: Date().addingTimeInterval(-120),
        onRestart: { _ in },
        onTap: {},
        onFilter: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Calm") {
    HomeNetworkCard(
        entries: [HomeNetworkCard.previewEntry(focused: true)],
        snapshot: HomeNetworkCard.previewSnapshot(offline: 0),
        healthUpdatedAt: Date(),
        onRestart: { _ in },
        onTap: {},
        onFilter: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

extension HomeNetworkCard {
    static func previewSnapshot(offline: Int) -> HomeSnapshot {
        let devices: [Device] = [.preview, .fallbackPreview]
        let availability: [String: Bool] = [
            Device.preview.friendlyName: true,
            Device.fallbackPreview.friendlyName: offline == 0,
        ]
        let states: [String: [String: JSONValue]] = [
            Device.preview.friendlyName: ["linkquality": .int(128)],
            Device.fallbackPreview.friendlyName: ["linkquality": .int(28), "battery": .int(8)],
        ]
        return HomeSnapshot(
            devices: devices, availability: availability, states: states,
            isConnected: true, isBridgeOnline: true, groupCount: 23,
            bridgeVersion: "2.9.2", bridgeCommit: nil,
            coordinatorType: "EmberZNet", coordinatorIEEEAddress: "0x4c5bb3fffe932a84",
            networkChannel: 20, panID: 54_074,
            isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
        )
    }

    static func previewEntry(
        name: String = "Loft bridge",
        focused: Bool = false,
        online: Bool = true,
        restart: Bool = false,
        reconnecting: Int? = nil
    ) -> HomeBridgeCardEntry {
        let info = BridgeInfo(
            version: "2.9.2",
            commit: "2b485a98c5f9c879e1e9b80ffae3c7a84b0dce8d",
            coordinator: CoordinatorInfo(type: "EmberZNet", ieeeAddress: "0x4c5bb3fffe932a84", meta: nil),
            network: NetworkInfo(channel: 20, panID: 54_074, extendedPanID: nil),
            logLevel: "info",
            permitJoin: false,
            permitJoinTimeout: nil,
            permitJoinEnd: nil,
            restartRequired: restart,
            config: nil
        )
        let health = BridgeHealth(
            healthy: true,
            responseTime: 12,
            process: BridgeHealth.ProcessStats(uptimeSec: 527_404, memoryUsedMb: 309.41, memoryPercent: 7.64),
            os: BridgeHealth.OSStats(loadAverage: [0.16, 0.03, 0.01], memoryUsedMb: 677.89, memoryPercent: 16.74),
            mqtt: BridgeHealth.MQTTStats(connected: true, queued: 0, published: 367_623, received: 15_575)
        )
        let state: ConnectionSessionController.State = reconnecting.map { .reconnecting(attempt: $0) } ?? .connected
        return HomeBridgeCardEntry(
            id: UUID(),
            name: name,
            host: "192.168.1.110",
            isFocused: focused,
            connectionState: state,
            isWebSocketConnected: reconnecting == nil,
            isBridgeOnline: online,
            info: info,
            health: health
        )
    }
}
