import SwiftUI

struct AppNotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    private var bridgeLogLevel: String? {
        environment.store.bridgeInfo?.logLevel
    }

    var body: some View {
        Form {
            Section {
                Text(summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            } footer: {
                Text("Defaults follow the Z2M bridge log level. Lowering the bridge level to error silences the chatty categories; raising it to debug enables more. Individual toggles here override the default.")
            }

            ForEach(NotificationCategory.Section.allCases, id: \.self) { section in
                Section(section.title) {
                    let categories = NotificationCategory.allCases.filter { $0.section == section }
                    ForEach(categories, id: \.self) { category in
                        Toggle(isOn: binding(for: category)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.displayName)
                                defaultHint(for: category)
                            }
                        }
                    }
                }
            }

            if environment.notificationPreferences.hasCustomSelection {
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        environment.notificationPreferences.resetToDefaults(bridgeLogLevel: bridgeLogLevel)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryText: String {
        let level = bridgeLogLevel ?? "info"
        if environment.notificationPreferences.hasCustomSelection {
            return "Showing your custom selection. Bridge log level is \(level)."
        }
        return "Following the Z2M bridge log level (\(level))."
    }

    @ViewBuilder
    private func defaultHint(for category: NotificationCategory) -> some View {
        let isOnByDefault = !environment.notificationPreferences.hasCustomSelection
            && environment.notificationPreferences.isEnabled(category, bridgeLogLevel: bridgeLogLevel)
        let hint: String = switch category.defaultMinimumLogLevel {
        case .error: "Always on"
        case .warning: "Default at warning or higher"
        case .info: "Default at info or higher"
        case .debug: "Default at debug only"
        case .optIn: "Off by default"
        }
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if isOnByDefault {
                Text("· on now")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func binding(for category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: {
                environment.notificationPreferences.isEnabled(category, bridgeLogLevel: bridgeLogLevel)
            },
            set: { newValue in
                environment.notificationPreferences.setEnabled(category, enabled: newValue, bridgeLogLevel: bridgeLogLevel)
            }
        )
    }
}

#Preview {
    NavigationStack {
        AppNotificationSettingsView()
            .environment(AppEnvironment())
    }
}
