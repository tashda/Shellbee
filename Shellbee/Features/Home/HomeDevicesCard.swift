import SwiftUI

struct HomeDevicesCard: View {
    let snapshot: HomeSnapshot
    let onTap: () -> Void
    let onFilter: (DeviceQuickFilter) -> Void

    private var hasAlerts: Bool {
        snapshot.devicesWithUpdates > 0
            || snapshot.scheduledUpdateDevices > 0
            || snapshot.updatingDevices > 0
            || snapshot.lowBatteryDevices > 0
            || snapshot.weakSignalDevices > 0
    }

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HomeCardTitle(symbol: "sensor.tag.radiowaves.forward.fill", title: "Devices", tint: .orange)
                statsRow
                if hasAlerts {
                    HomeCardAlertList { alertRows }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .gesture(TapGesture().onEnded(onTap), including: .gesture)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            statButton(.all, value: "\(snapshot.totalDevices)", label: "Total")
            statButton(.online, value: "\(snapshot.onlineDevices)", label: "Online")
            statButton(.offline, value: "\(snapshot.offlineDevices)", label: "Offline",
                       valueColor: snapshot.offlineDevices > 0 ? .red : .primary)
            statButton(.availabilityOff, value: "\(snapshot.availabilityOffDevices)", label: "Availability off",
                       valueColor: snapshot.availabilityOffDevices > 0 ? .secondary : .primary)
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
        if snapshot.scheduledUpdateDevices > 0 {
            HomeCardAlertRow(
                symbol: "calendar.badge.clock",
                title: "\(snapshot.scheduledUpdateDevices) scheduled for update",
                color: .indigo,
                action: { onFilter(.updatesAvailable) }
            )
        }
        if snapshot.updatingDevices > 0 {
            HomeCardAlertRow(
                symbol: "arrow.up.circle.fill",
                title: "\(snapshot.updatingDevices) updating now",
                color: .green,
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
    HomeDevicesCard(snapshot: HomeDevicesCard.previewSnapshot, onTap: {}, onFilter: { _ in })
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
