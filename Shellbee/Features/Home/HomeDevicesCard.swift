import SwiftUI

struct HomeDevicesCard: View {
    let snapshot: HomeSnapshot
    let onFilter: (DeviceQuickFilter) -> Void

    private var hasAlerts: Bool {
        snapshot.devicesWithUpdates > 0 || snapshot.lowBatteryDevices > 0 || snapshot.weakSignalDevices > 0
    }

    var body: some View {
        HomeCardContainer(tint: .blue) {
            header
            Divider().padding(.vertical, DesignTokens.Spacing.sm)
            statsRow
            if hasAlerts {
                Divider().padding(.vertical, DesignTokens.Spacing.sm)
                VStack(spacing: DesignTokens.Spacing.sm) { alertRows }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "cpu")
                .font(.system(size: DesignTokens.Size.summaryRowSymbol, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: DesignTokens.Size.summaryRowSymbolFrame, height: DesignTokens.Size.summaryRowSymbolFrame)
                .background(Color.blue.opacity(DesignTokens.Opacity.subtleFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.summaryRowSymbolBackground, style: .continuous))
            Text("Devices")
                .font(.headline)
        }
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            statButton(.all, value: "\(snapshot.totalDevices)", label: "Total")
            statButton(.online, value: "\(snapshot.onlineDevices)", label: "Online",
                       valueColor: snapshot.onlineDevices > 0 ? .green : .secondary)
            statButton(.offline, value: "\(snapshot.offlineDevices)", label: "Offline",
                       valueColor: snapshot.offlineDevices > 0 ? .red : .secondary)
        }
    }

    private func statButton(_ filter: DeviceQuickFilter, value: String, label: String, valueColor: Color = .primary) -> some View {
        Button { onFilter(filter) } label: {
            HomeStatCell(value: value, label: label, valueColor: valueColor)
        }
        .buttonStyle(StatCellButtonStyle())
    }

    @ViewBuilder
    private var alertRows: some View {
        if snapshot.devicesWithUpdates > 0 {
            HomeCardAlertRow(
                symbol: "arrow.down.circle.fill",
                title: "\(snapshot.devicesWithUpdates) firmware update\(snapshot.devicesWithUpdates == 1 ? "" : "s") ready",
                color: .blue,
                action: { onFilter(.updatesAvailable) }
            )
        }
        if snapshot.lowBatteryDevices > 0 {
            HomeCardAlertRow(
                symbol: "battery.25",
                title: "\(snapshot.lowBatteryDevices) low battery",
                color: .red,
                action: { onFilter(.batteryLow) }
            )
        }
        if snapshot.weakSignalDevices > 0 {
            HomeCardAlertRow(
                symbol: "wifi.exclamationmark",
                title: "\(snapshot.weakSignalDevices) weak signal",
                color: .orange,
                action: { onFilter(.weakSignal) }
            )
        }
    }
}

#Preview {
    HomeDevicesCard(snapshot: HomeDevicesCard.previewSnapshot, onFilter: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}

private extension HomeDevicesCard {
    static var previewSnapshot: HomeSnapshot {
        HomeSnapshot(
            devices: [],
            availability: [:],
            states: [
                Device.preview.friendlyName: [
                    "battery": .int(12),
                    "linkquality": .int(20),
                    "update": .object(["state": .string("available")])
                ]
            ],
            isConnected: true, isBridgeOnline: true, groupCount: 23,
            bridgeVersion: "2.9.2", bridgeCommit: nil,
            coordinatorType: nil, coordinatorIEEEAddress: nil,
            networkChannel: nil, panID: nil,
            isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
        )
    }
}
