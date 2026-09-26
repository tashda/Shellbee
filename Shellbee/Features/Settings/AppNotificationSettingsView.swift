import SwiftUI

struct AppNotificationSettingsView: View {
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isActivityCenterEnabled = true
    @AppStorage(ActivityAccessoryDisplayMode.storageKey) private var displayModeRaw = ActivityAccessoryDisplayMode.latestActivity.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("Show Activity Center", isOn: $isActivityCenterEnabled)
                Picker("Show", selection: $displayModeRaw) {
                    ForEach(ActivityAccessoryDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .disabled(!isActivityCenterEnabled)

                ActivityCenterPresentationPreview(mode: displayMode)
                    .opacity(isActivityCenterEnabled ? 1 : DesignTokens.Opacity.disabled)
            } footer: {
                Text(displayMode.detail)
            }

            Section("Notifications") {
                NavigationLink { ActivityNotificationSettingsView() } label: {
                    SettingsNavigationLabel(
                        title: "Notifications",
                        systemImage: "bell.badge.fill",
                        color: .red
                    )
                }
            }
        }
        .navigationTitle("Activity Center")
        .navigationBarTitleDisplayMode(.inline)
    }
    private var displayMode: ActivityAccessoryDisplayMode {
        ActivityAccessoryDisplayMode(rawValue: displayModeRaw) ?? .latestActivity
    }
}

private struct ActivityCenterPresentationPreview: View {
    let mode: ActivityAccessoryDisplayMode

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            ActivityAccessorySummary(
                mode: mode,
                latestActivity: Self.latestActivity,
                latestAttention: Self.latestAttention,
                recentActivityCount: 4,
                recentAttentionCount: 1,
                isInline: false
            )
            .glassEffectIfAvailable(
                in: RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.lg,
                    style: .continuous
                )
            )
            .padding(.vertical, DesignTokens.Spacing.xs)
            .accessibilityLabel("Activity Center preview")
        } else {
            Text("Activity Center is available on iOS 26 and later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static let previewBridgeID = UUID()

    private static let latestActivity = BridgeBoundLogEntry(
        bridgeID: previewBridgeID,
        bridgeName: "Kitchen Light",
        entry: LogEntry(
            id: UUID(),
            timestamp: .now,
            level: .info,
            category: .stateChange,
            namespace: nil,
            message: "Kitchen Light brightness changed",
            deviceName: "Kitchen Light",
            activityTitle: "Brightness changed",
            activitySubtitle: "72%"
        )
    )

    private static let latestAttention = BridgeBoundLogEntry(
        bridgeID: previewBridgeID,
        bridgeName: "Bedroom Hue",
        entry: LogEntry(
            id: UUID(),
            timestamp: .now,
            level: .warning,
            category: .bridgeActivity,
            namespace: nil,
            message: "Firmware update available",
            deviceName: "Bedroom Hue",
            isActivityAttention: true,
            activityTitle: "Firmware update available",
            activitySubtitle: "Bedroom Hue"
        )
    )
}

#Preview {
    NavigationStack {
        AppNotificationSettingsView()
    }
    .configuredTopScrollEdgeEffect()
}
