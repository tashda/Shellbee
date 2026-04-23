import SwiftUI

struct HomeBridgeCard: View {
    let snapshot: HomeSnapshot
    let health: BridgeHealth?
    var serverName: String? = nil
    var connectionState: ConnectionSessionController.State = .idle
    let onRestart: () -> Void

    private var isReconnecting: Bool {
        if case .reconnecting = connectionState { return true }
        return false
    }

    private var reconnectAttempt: Int {
        if case .reconnecting(let n) = connectionState { return n }
        return 0
    }

    private var headerTitle: String {
        if let serverName, !serverName.isEmpty { return serverName }
        return "Zigbee2MQTT"
    }

    private var headerDotColor: Color {
        if isReconnecting { return .orange }
        return snapshot.isBridgeOnline ? .green : .red
    }

    @State private var latestVersion: String? = nil
    @State private var lastVersionFetch: Date? = nil

    private var updateAvailable: Bool {
        guard let latest = latestVersion.flatMap(Z2MVersion.parse),
              let current = snapshot.bridgeVersion.flatMap(Z2MVersion.parse) else { return false }
        return latest > current
    }

    private var hasMemoryAlert: Bool {
        let z2mHigh = (health?.process?.memoryPercent ?? 0) > 30
        let osHigh  = (health?.os?.memoryPercent ?? 0) > 85
        return z2mHigh || osHigh
    }

    private var hasAlerts: Bool {
        updateAvailable || snapshot.restartRequired || snapshot.isPermitJoinActive || hasMemoryAlert
    }

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                header
                if health?.process != nil || health?.responseTime != nil {
                    statsRow
                }
                statusRow
                if hasAlerts {
                    HomeCardAlertList { alertRows }
                }
            }
        }
        .task(id: snapshot.bridgeVersion) {
            await fetchLatestVersion()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            HomeCardTitle(symbol: "antenna.radiowaves.left.and.right", title: headerTitle, tint: .teal)
                .lineLimit(1)
            if isReconnecting {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("Reconnecting (\(reconnectAttempt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            if let uptime = health?.process?.uptimeFormatted {
                HomeStatCell(value: uptime, label: "Uptime")
            }
            if let published = health?.mqtt?.published {
                HomeStatCell(value: formatCount(published), label: "Published")
            }
            if let received = health?.mqtt?.received {
                HomeStatCell(value: formatCount(received), label: "Received")
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 0..<1_000:       return "\(n)"
        case 1_000..<1_000_000: return String(format: "%.0fK", Double(n) / 1_000)
        default:              return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }

    private var mqttDown: Bool {
        if let connected = health?.mqtt?.connected { return !connected }
        return false
    }

    private var statusRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if !snapshot.isConnected {
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
        HStack(spacing: 6) {
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
        if snapshot.restartRequired {
            HomeCardAlertRow(
                symbol: "arrow.triangle.2.circlepath.circle.fill",
                title: "Restart required to apply configuration",
                color: .orange,
                action: onRestart
            )
        }
        if snapshot.isPermitJoinActive {
            let label = snapshot.permitJoinRemaining.map { "Permit Join open — \($0)s remaining" } ?? "Permit Join open"
            HomeCardAlertRow(symbol: "person.crop.circle.badge.plus", title: label, color: .orange, action: nil)
        }
        if let pct = health?.process?.memoryPercent, pct > 30 {
            HomeCardAlertRow(
                symbol: "memorychip",
                title: "High Z2M memory (\(Int(pct))%)",
                color: .orange,
                action: nil
            )
        }
        if let pct = health?.os?.memoryPercent, pct > 85 {
            HomeCardAlertRow(
                symbol: "memorychip",
                title: "High system memory (\(Int(pct))%)",
                color: .orange,
                action: nil
            )
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

#Preview {
    HomeBridgeCard(snapshot: HomeBridgeCard.previewSnapshot, health: HomeBridgeCard.previewHealth, onRestart: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

private extension HomeBridgeCard {
    static var previewSnapshot: HomeSnapshot {
        HomeSnapshot(
            devices: [], availability: [:], states: [:],
            isConnected: true, isBridgeOnline: true, groupCount: 3,
            bridgeVersion: "2.9.2", bridgeCommit: "2b485a98c5f9",
            coordinatorType: "EmberZNet", coordinatorIEEEAddress: "0x4c5bb3fffe932a84",
            networkChannel: 20, panID: 54_074,
            isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
        )
    }

    static var previewHealth: BridgeHealth {
        BridgeHealth(
            healthy: true,
            responseTime: 12,
            process: BridgeHealth.ProcessStats(uptimeSec: 527404, memoryUsedMb: 309.41, memoryPercent: 7.64),
            os: BridgeHealth.OSStats(loadAverage: [0.16, 0.03, 0.01], memoryUsedMb: 677.89, memoryPercent: 16.74),
            mqtt: BridgeHealth.MQTTStats(connected: true, queued: 0, published: 367_623, received: 15_575)
        )
    }
}
