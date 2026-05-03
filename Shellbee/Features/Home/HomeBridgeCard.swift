import SwiftUI

struct HomeBridgeCard: View {
    let entries: [HomeBridgeCardEntry]
    let onRestart: (UUID) -> Void
    var onSelectBridge: ((UUID) -> Void)? = nil

    var body: some View {
        if entries.count >= 2 {
            multiBridgeCard
        } else {
            HomeBridgeCardSingle(entry: entries.first, onRestart: onRestart)
        }
    }

    private var multiBridgeCard: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HomeCardTitle(symbol: "antenna.radiowaves.left.and.right", title: "Bridges", tint: .teal)
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        HomeBridgeCardRow(
                            entry: entry,
                            onRestart: { onRestart(entry.id) },
                            onSelect: onSelectBridge.map { handler in { handler(entry.id) } }
                        )
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

/// Single-bridge layout — preserves the legacy stat/status/alert presentation.
private struct HomeBridgeCardSingle: View {
    let entry: HomeBridgeCardEntry?
    let onRestart: (UUID) -> Void

    @State private var latestVersion: String? = nil
    @State private var lastVersionFetch: Date? = nil

    private var headerTitle: String {
        entry?.name.isEmpty == false ? entry!.name : "Zigbee2MQTT"
    }

    private var updateAvailable: Bool {
        guard let latest = latestVersion.flatMap(Z2MVersion.parse),
              let current = entry?.version.flatMap(Z2MVersion.parse) else { return false }
        return latest > current
    }

    private var hasMemoryAlert: Bool {
        let z2mHigh = (entry?.health?.process?.memoryPercent ?? 0) > 30
        let osHigh  = (entry?.health?.os?.memoryPercent ?? 0) > 85
        return z2mHigh || osHigh
    }

    private var hasAlerts: Bool {
        updateAvailable
            || entry?.restartRequired == true
            || entry?.isPermitJoinActive == true
            || hasMemoryAlert
    }

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                header
                if entry?.health?.process != nil || entry?.health?.responseTime != nil {
                    statsRow
                }
                statusRow
                if hasAlerts {
                    HomeCardAlertList { alertRows }
                }
            }
        }
        .task(id: entry?.version) {
            await fetchLatestVersion()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            HomeCardTitle(symbol: "antenna.radiowaves.left.and.right", title: headerTitle, tint: .teal)
                .lineLimit(1)
            if entry?.isReconnecting == true {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ProgressView().controlSize(.mini)
                    Text("Reconnecting (\(entry?.reconnectAttempt ?? 0))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            if let uptime = entry?.health?.process?.uptimeFormatted {
                HomeStatCell(value: uptime, label: "Uptime")
            }
            if let published = entry?.health?.mqtt?.published {
                HomeStatCell(value: formatCount(published), label: "Published")
            }
            if let received = entry?.health?.mqtt?.received {
                HomeStatCell(value: formatCount(received), label: "Received")
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 0..<1_000:           return "\(n)"
        case 1_000..<1_000_000:   return String(format: "%.0fK", Double(n) / 1_000)
        default:                  return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }

    private var mqttDown: Bool {
        if let connected = entry?.health?.mqtt?.connected { return !connected }
        return false
    }

    private var statusRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if entry?.isWebSocketConnected != true {
                statusLine(symbol: "exclamationmark.triangle.fill", tint: .red, text: "WebSocket disconnected")
            } else if mqttDown {
                statusLine(symbol: "exclamationmark.triangle.fill", tint: .orange, text: "MQTT disconnected")
            } else if !hasAlerts {
                statusLine(symbol: "checkmark.seal.fill", tint: .green, text: "Connected and healthy")
            } else {
                statusLine(symbol: "checkmark.seal.fill", tint: .green, text: "Connected")
            }
            Spacer()
        }
    }

    private func statusLine(symbol: String, tint: Color, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var alertRows: some View {
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
        if entry?.isPermitJoinActive == true {
            HomeCardAlertRow(symbol: "person.crop.circle.badge.plus", title: "Permit Join open", color: .orange, action: nil)
        }
        if let pct = entry?.health?.process?.memoryPercent, pct > 30 {
            HomeCardAlertRow(symbol: "memorychip", title: "High Z2M memory (\(Int(pct))%)", color: .orange, action: nil)
        }
        if let pct = entry?.health?.os?.memoryPercent, pct > 85 {
            HomeCardAlertRow(symbol: "memorychip", title: "High system memory (\(Int(pct))%)", color: .orange, action: nil)
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

#Preview("Single") {
    HomeBridgeCard(entries: [HomeBridgeCard.previewEntry(focused: true)], onRestart: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Multi") {
    HomeBridgeCard(
        entries: [
            HomeBridgeCard.previewEntry(focused: true),
            HomeBridgeCard.previewEntry(name: "Lab", online: true, restart: true),
            HomeBridgeCard.previewEntry(name: "Garage", reconnecting: 3)
        ],
        onRestart: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

extension HomeBridgeCard {
    static func previewEntry(
        name: String = "Main",
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
            isFocused: focused,
            connectionState: state,
            isWebSocketConnected: reconnecting == nil,
            isBridgeOnline: online,
            info: info,
            health: health
        )
    }
}
