import SwiftUI

struct HomeBridgeCard: View {
    let snapshot: HomeSnapshot
    let health: BridgeHealth?
    let onRestart: () -> Void

    @State private var latestVersion: String? = nil

    private var tint: Color { snapshot.isBridgeOnline ? .green : .red }

    private var hasAlerts: Bool {
        updateAvailable || snapshot.restartRequired || snapshot.isPermitJoinActive
    }

    private var updateAvailable: Bool {
        guard let latest = latestVersion.flatMap(Z2MVersion.parse),
              let current = snapshot.bridgeVersion.flatMap(Z2MVersion.parse) else { return false }
        return latest > current
    }

    var body: some View {
        HomeCardContainer(tint: tint) {
            header
            Divider().padding(.vertical, DesignTokens.Spacing.sm)
            if let health, health.process != nil || health.mqtt != nil {
                healthStatsRow(health)
                Divider().padding(.vertical, DesignTokens.Spacing.sm)
            }
            VStack(spacing: DesignTokens.Spacing.sm) { alertRows }
        }
        .task(id: snapshot.bridgeVersion) {
            await fetchLatestVersion()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: snapshot.isBridgeOnline ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    .font(.system(size: DesignTokens.Size.summaryRowSymbol, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: DesignTokens.Size.summaryRowSymbolFrame, height: DesignTokens.Size.summaryRowSymbolFrame)
                    .background(tint.opacity(DesignTokens.Opacity.subtleFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Zigbee2MQTT")
                        .font(.headline)
                    if let coordinator = snapshot.coordinatorType {
                        Text(coordinator)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                if let version = snapshot.bridgeVersion, let url = snapshot.releaseURL {
                    Link(version, destination: url)
                        .font(.subheadline.weight(.semibold))
                } else if let version = snapshot.bridgeVersion {
                    Text(version)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: DesignTokens.Size.statusDot * 0.7, height: DesignTokens.Size.statusDot * 0.7)
            Text(snapshot.isBridgeOnline ? "Online" : "Offline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func healthStatsRow(_ h: BridgeHealth) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            if let uptime = h.process?.uptimeFormatted {
                HomeStatCell(value: uptime, label: "Uptime")
            }
            if let ram = h.process?.rssMB {
                HomeStatCell(value: ram, label: "Z2M RAM",
                             subtitle: h.process?.ramPercentFormatted)
            }
            if let osRam = h.os?.ramMB {
                HomeStatCell(value: osRam, label: "OS RAM",
                             subtitle: h.os?.ramPercentFormatted)
            }
        }
    }

    @ViewBuilder
    private var alertRows: some View {
        if updateAvailable, let latest = latestVersion, let url = URL(string: "https://github.com/Koenkk/zigbee2mqtt/releases/tag/\(latest)") {
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
        if !hasAlerts {
            HomeCardAlertRow(symbol: "checkmark.circle.fill", title: "Bridge healthy", color: .green, action: nil)
        }
    }

    private func fetchLatestVersion() async {
        guard let url = URL(string: "https://api.github.com/repos/Koenkk/zigbee2mqtt/releases/latest") else { return }
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
            isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: true
        )
    }

    static var previewHealth: BridgeHealth {
        BridgeHealth(
            healthy: true,
            responseTime: nil,
            process: BridgeHealth.ProcessStats(uptimeSec: 527404, memoryUsedMb: 309.41, memoryPercent: 7.64),
            os: BridgeHealth.OSStats(loadAverage: [0.16, 0.03, 0.01], memoryUsedMb: 677.89, memoryPercent: 16.74),
            mqtt: BridgeHealth.MQTTStats(connected: true, queued: 0, published: 367_623, received: 15_575)
        )
    }
}
