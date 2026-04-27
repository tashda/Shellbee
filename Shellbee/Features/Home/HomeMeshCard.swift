import SwiftUI

struct HomeMeshCard: View {
    let snapshot: HomeSnapshot
    let onTap: () -> Void
    let onFilter: (DeviceQuickFilter) -> Void

    private var hasAlerts: Bool {
        snapshot.interviewingDevices > 0 || snapshot.unsupportedDevices > 0 || snapshot.disabledDevices > 0
    }

    var body: some View {
        HomeCardContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HomeCardTitle(symbol: "point.3.connected.trianglepath.dotted", title: "Mesh", tint: .indigo)
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
    HomeMeshCard(snapshot: HomeMeshCard.previewSnapshot, onTap: {}, onFilter: { _ in })
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
