import SwiftUI

struct HomeMeshCard: View {
    let snapshot: HomeSnapshot
    let onFilter: (DeviceQuickFilter) -> Void

    private var hasAlerts: Bool {
        snapshot.interviewingDevices > 0 || snapshot.unsupportedDevices > 0 || snapshot.disabledDevices > 0
    }

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                header
                statsRow
                if hasAlerts {
                    VStack(spacing: DesignTokens.Spacing.sm) { alertRows }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Mesh")
                    .font(.headline)
                if let coordinator = snapshot.coordinatorType {
                    Text(coordinator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let channel = snapshot.networkChannel {
                    Text("ch \(channel)")
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if let panID = snapshot.panIDText {
                    Text(panID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            Button { onFilter(.router) } label: {
                HomeStatCell(value: "\(snapshot.routerCount)", label: "Routers")
            }
            .buttonStyle(StatCellButtonStyle())

            Button { onFilter(.endDevice) } label: {
                HomeStatCell(value: "\(snapshot.endDeviceCount)", label: "End devices")
            }
            .buttonStyle(StatCellButtonStyle())

            if let lqi = snapshot.averageLinkQuality {
                HomeStatCell(value: "\(lqi)", label: "Avg LQI", valueColor: lqi >= 60 ? .primary : .red)
            }
        }
    }

    @ViewBuilder
    private var alertRows: some View {
        if snapshot.interviewingDevices > 0 {
            HomeCardAlertRow(
                symbol: "waveform.path.ecg",
                title: "\(snapshot.interviewingDevices) interviewing",
                color: .indigo,
                action: { onFilter(.interviewing) }
            )
        }
        if snapshot.unsupportedDevices > 0 {
            HomeCardAlertRow(
                symbol: "exclamationmark.triangle.fill",
                title: "\(snapshot.unsupportedDevices) unsupported",
                color: .orange,
                action: { onFilter(.unsupported) }
            )
        }
        if snapshot.disabledDevices > 0 {
            HomeCardAlertRow(
                symbol: "nosign",
                title: "\(snapshot.disabledDevices) disabled",
                color: .secondary,
                action: nil
            )
        }
    }
}

#Preview {
    HomeMeshCard(snapshot: HomeMeshCard.previewSnapshot, onFilter: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}

private extension HomeMeshCard {
    static var previewSnapshot: HomeSnapshot {
        HomeSnapshot(
            devices: [], availability: [:], states: [:],
            isConnected: true, isBridgeOnline: true, groupCount: 0,
            bridgeVersion: nil, bridgeCommit: nil,
            coordinatorType: "EmberZNet", coordinatorIEEEAddress: "0x4c5bb3fffe932a84",
            networkChannel: 20, panID: 54_074,
            isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
        )
    }
}
