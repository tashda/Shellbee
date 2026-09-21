import SwiftUI

struct AppNotificationSettingsView: View {
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isActivityCenterEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Show Activity Center", isOn: $isActivityCenterEnabled)
                NavigationLink { ActivityCenterPresentationSettingsView() } label: {
                    Label("Presentation", systemImage: "rectangle.bottomthird.inset.filled")
                }
                NavigationLink { ActivityNotificationSettingsView() } label: {
                    Label("Notifications", systemImage: "bell.badge.fill")
                }
            }
        }
        .navigationTitle("Activity Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ActivityCenterPresentationSettingsView: View {
    @AppStorage(ActivityAccessoryDisplayMode.storageKey) private var displayModeRaw = ActivityAccessoryDisplayMode.summary.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Show", selection: $displayModeRaw) {
                    ForEach(ActivityAccessoryDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            }

            Section("Preview") {
                ActivityCenterPresentationPreview(mode: displayMode)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Presentation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayMode: ActivityAccessoryDisplayMode {
        ActivityAccessoryDisplayMode(rawValue: displayModeRaw) ?? .summary
    }
}

private struct ActivityCenterPresentationPreview: View {
    let mode: ActivityAccessoryDisplayMode

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var title: String {
        switch mode {
        case .latestActivity: "Kitchen Light changed"
        case .summary: "4 recent events"
        case .notificationsOnly: "Firmware update available"
        }
    }

    private var subtitle: String {
        switch mode {
        case .latestActivity: "A moment ago"
        case .summary: "View Activity"
        case .notificationsOnly: "Bedroom Hue"
        }
    }

    private var symbol: String {
        mode == .notificationsOnly ? "bell.badge.fill" : "list.bullet.rectangle.fill"
    }

    private var color: Color {
        mode == .notificationsOnly ? .orange : .secondary
    }
}

#Preview {
    NavigationStack {
        AppNotificationSettingsView()
    }
    .configuredTopScrollEdgeEffect()
}
