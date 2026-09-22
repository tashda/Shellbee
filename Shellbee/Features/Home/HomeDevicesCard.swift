import SwiftUI

/// Everything the user owns: devices and the groups that address them.
///
/// Trouble is carried by the figures themselves — an unreachable count turns
/// red and grows a caption saying how long it has been quiet. There is no
/// badge, chip or coloured edge, so the only coloured thing on a healthy card
/// is nothing at all, and the card collapses to a single line.
struct HomeDevicesCard: View {
    let snapshot: HomeSnapshot
    let groupCount: Int
    let onTap: () -> Void
    let onFilter: (DeviceQuickFilter) -> Void

    /// One figure in the stat row, resolved from the snapshot.
    private struct Stat: Identifiable {
        let id: String
        let label: String
        let value: String
        let count: Int
        var color: Color = .primary
        var caption: String? = nil
        var filter: DeviceQuickFilter
    }

    /// The trouble worth a slot, most severe first. Firmware updates are last
    /// because an update waiting is news rather than a fault.
    private var troubleStats: [Stat] {
        var stats: [Stat] = []
        if snapshot.offlineDevices > 0 {
            stats.append(Stat(
                id: "offline", label: "Offline", value: "\(snapshot.offlineDevices)",
                count: snapshot.offlineDevices, color: .red,
                caption: snapshot.offlineCaption, filter: .offline
            ))
        }
        if snapshot.lowBatteryDevices > 0 {
            stats.append(Stat(
                id: "battery", label: "Battery", value: "\(snapshot.lowBatteryDevices)",
                count: snapshot.lowBatteryDevices, color: .red,
                caption: snapshot.lowBatteryCaption, filter: .batteryLow
            ))
        }
        if snapshot.weakSignalDevices > 0 {
            stats.append(Stat(
                id: "signal", label: "Weak signal", value: "\(snapshot.weakSignalDevices)",
                count: snapshot.weakSignalDevices, color: .orange,
                caption: snapshot.weakSignalCaption, filter: .weakSignal
            ))
        }
        if snapshot.devicesWithUpdates > 0 {
            stats.append(Stat(
                id: "updates", label: "Updates", value: "\(snapshot.devicesWithUpdates)",
                count: snapshot.devicesWithUpdates, color: .blue,
                caption: "ready", filter: .updatesAvailable
            ))
        }
        return stats
    }

    /// Always three across: the total, then whatever needs attention. When
    /// only one thing is wrong, the reachable count fills the third slot
    /// rather than leaving a hole in the row.
    private var stats: [Stat] {
        let total = Stat(
            id: "total", label: "Devices", value: "\(snapshot.totalDevices)",
            count: snapshot.totalDevices, filter: .all
        )
        let trouble = Array(troubleStats.prefix(2))
        guard trouble.count < 2 else { return [total] + trouble }
        let online = Stat(
            id: "online", label: "Answering", value: "\(snapshot.onlineDevices)",
            count: snapshot.onlineDevices, filter: .online
        )
        return [total] + trouble + [online]
    }

    /// Facts worth keeping but not worth a figure. Also tacked onto the
    /// collapsed line so nothing disappears on a healthy day.
    private var secondaryFacts: [String] {
        var parts: [String] = []
        if groupCount > 0 { parts.append("\(groupCount) group\(groupCount == 1 ? "" : "s")") }
        if snapshot.availabilityOffDevices > 0 { parts.append("\(snapshot.availabilityOffDevices) untracked") }
        if snapshot.unsupportedDevices > 0 { parts.append("\(snapshot.unsupportedDevices) unsupported") }
        if snapshot.disabledDevices > 0 { parts.append("\(snapshot.disabledDevices) disabled") }
        return parts
    }

    private var calmDetail: String {
        var parts = ["\(snapshot.totalDevices) · all answering"]
        if snapshot.devicesWithUpdates > 0 {
            parts.append("\(snapshot.devicesWithUpdates) update\(snapshot.devicesWithUpdates == 1 ? "" : "s")")
        }
        parts.append(contentsOf: secondaryFacts)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        SwiftUI.Group {
            if snapshot.devicesAreCalm {
                HomeCardContainer(padding: DesignTokens.Spacing.md) {
                    HomeCalmSummary(
                        symbol: "sensor.tag.radiowaves.forward.fill",
                        title: "Devices",
                        tint: .orange,
                        detail: calmDetail
                    )
                }
            } else {
                HomeCardContainer {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        HomeCardTitle(
                            symbol: "sensor.tag.radiowaves.forward.fill",
                            title: "Devices",
                            tint: .orange
                        )
                        HomeStatRow {
                            ForEach(stats) { stat in
                                Button { onFilter(stat.filter) } label: {
                                    HomeStatCell(
                                        label: stat.label,
                                        value: stat.value,
                                        valueColor: stat.color,
                                        caption: stat.caption,
                                        count: stat.count
                                    )
                                }
                                .buttonStyle(StatCellButtonStyle())
                            }
                        }
                        if !secondaryFacts.isEmpty {
                            Text(secondaryFacts.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .gesture(TapGesture().onEnded(onTap), including: .gesture)
    }
}

#Preview("Trouble") {
    HomeDevicesCard(snapshot: HomeDevicesCard.previewSnapshot(healthy: false), groupCount: 23, onTap: {}, onFilter: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Calm") {
    HomeDevicesCard(snapshot: HomeDevicesCard.previewSnapshot(healthy: true), groupCount: 23, onTap: {}, onFilter: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}

extension HomeDevicesCard {
    static func previewSnapshot(healthy: Bool) -> HomeSnapshot {
        let devices: [Device] = [.preview, .fallbackPreview]
        let states: [String: [String: JSONValue]] = [
            Device.preview.friendlyName: [
                "battery": .int(healthy ? 78 : 8),
                "linkquality": .int(128),
                "update": .object(["state": .string("available")]),
                "last_seen": .string("2026-09-22T14:02:00Z"),
            ],
            Device.fallbackPreview.friendlyName: ["linkquality": .int(120)],
        ]
        return HomeSnapshot(
            devices: devices,
            availability: [
                Device.preview.friendlyName: healthy,
                Device.fallbackPreview.friendlyName: true,
            ],
            states: states,
            isConnected: true, isBridgeOnline: true, groupCount: 23,
            bridgeVersion: "2.9.2", bridgeCommit: nil,
            coordinatorType: nil, coordinatorIEEEAddress: nil,
            networkChannel: nil, panID: nil,
            isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
        )
    }
}
