import SwiftUI

struct HomeCardsSettingsView: View {
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount = HomeSettings.recentEventsCountDefault
    @AppStorage(HomeSettings.cardDisplayKey(.bridge)) private var bridgeCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.devices)) private var devicesCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.groups)) private var groupsCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.mesh)) private var meshCardDisplayRaw = HomeCardDisplayMode.one.rawValue
    @AppStorage(HomeSettings.cardDisplayKey(.recentEvents)) private var recentEventsCardDisplayRaw = HomeCardDisplayMode.one.rawValue

    var body: some View {
        Form {
            Section("Home Preview") {
                HomeCardsPreview(
                    recentEventsCount: recentEventsCount,
                    displayModes: displayModes
                )
                .listRowInsets(EdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.sm,
                    trailing: DesignTokens.Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .allowsHitTesting(false)
            }

            Section {
                Picker("Recent Events", selection: $recentEventsCount) {
                    ForEach(HomeSettings.recentEventsOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            } header: {
                Text("Content")
            }

            Section {
                displayPicker("Bridges", selection: $bridgeCardDisplayRaw)
                displayPicker("Devices", selection: $devicesCardDisplayRaw)
                displayPicker("Groups", selection: $groupsCardDisplayRaw)
                displayPicker("Mesh", selection: $meshCardDisplayRaw)
                displayPicker("Recent Events", selection: $recentEventsCardDisplayRaw)
            } header: {
                Text("Card Layout")
            }

        }
        .navigationTitle("Home Cards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayModes: [HomeCardID: HomeCardDisplayMode] {
        [
            .bridge: displayMode(for: bridgeCardDisplayRaw),
            .devices: displayMode(for: devicesCardDisplayRaw),
            .groups: displayMode(for: groupsCardDisplayRaw),
            .mesh: displayMode(for: meshCardDisplayRaw),
            .recentEvents: displayMode(for: recentEventsCardDisplayRaw)
        ]
    }

    private func displayPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(HomeCardDisplayMode.allCases, id: \.rawValue) { mode in
                Text(mode.label).tag(mode.rawValue)
            }
        }
    }

    private func displayMode(for value: String) -> HomeCardDisplayMode {
        HomeCardDisplayMode(rawValue: value) ?? .one
    }
}

private struct HomeCardsPreview: View {
    let recentEventsCount: Int
    let displayModes: [HomeCardID: HomeCardDisplayMode]

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(HomeCardID.allCases) { card in
                if displayModes[card] == .perBridge {
                    cardPreview(card, bridgeName: "Home")
                    cardPreview(card, bridgeName: "Studio")
                } else {
                    cardPreview(card, bridgeName: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func cardPreview(_ card: HomeCardID, bridgeName: String?) -> some View {
        switch card {
        case .bridge:
            HomeBridgeCard(
                entries: [Self.bridgeEntry(name: bridgeName ?? "Zigbee2MQTT")],
                onRestart: { _ in },
                fetchesLatestVersion: false
            )
        case .devices:
            HomeDevicesCard(
                snapshot: Self.snapshot,
                bridgeName: bridgeName,
                onTap: {},
                onFilter: { _ in }
            )
        case .groups:
            HomeGroupsCard(count: Self.snapshot.groupCount, bridgeName: bridgeName, onTap: {})
        case .mesh:
            HomeMeshCard(
                snapshot: Self.snapshot,
                bridgeName: bridgeName,
                onTap: {},
                onFilter: { _ in }
            )
        case .recentEvents:
            HomeLogsCard(
                entries: Array(LogEntry.previewEntries.prefix(recentEventsCount)),
                bridgeName: bridgeName,
                onOpenEntry: { _ in },
                onOpenAll: {}
            )
        }
    }

    private static func bridgeEntry(name: String) -> HomeBridgeCardEntry {
        HomeBridgeCardEntry(
            id: UUID(),
            name: name,
            isFocused: true,
            connectionState: .connected,
            isWebSocketConnected: true,
            isBridgeOnline: true,
            info: nil,
            health: nil
        )
    }

    private static let snapshot = HomeSnapshot(
        devices: [.preview, .fallbackPreview, previewRouter],
        availability: [
            Device.preview.friendlyName: true,
            Device.fallbackPreview.friendlyName: false,
            previewRouter.friendlyName: true
        ],
        states: [
            Device.preview.friendlyName: ["linkquality": .int(132)],
            Device.fallbackPreview.friendlyName: ["battery": .int(18), "linkquality": .int(42)],
            previewRouter.friendlyName: ["linkquality": .int(96)]
        ],
        isConnected: true,
        isBridgeOnline: true,
        groupCount: 3,
        bridgeVersion: nil,
        bridgeCommit: nil,
        coordinatorType: "EmberZNet",
        coordinatorIEEEAddress: nil,
        networkChannel: 20,
        panID: nil,
        isPermitJoinActive: false,
        permitJoinEnd: nil,
        restartRequired: false
    )

    private static let previewRouter = Device(
        ieeeAddress: "preview-router",
        type: .router,
        networkAddress: 3,
        supported: true,
        friendlyName: "Kitchen Router",
        disabled: false,
        definition: nil,
        powerSource: "mains",
        interviewCompleted: true,
        interviewing: false
    )
}

#Preview {
    NavigationStack {
        HomeCardsSettingsView()
    }
}
