import SwiftUI

struct ActivityNotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    private var connectedBridgeLevels: [(session: BridgeSession, level: String)] {
        environment.registry.orderedSessions
            .filter(\.isConnected)
            .map { ($0, $0.store.bridgeInfo?.logLevel ?? "info") }
    }

    private var effectiveLevel: NotificationCategory.DefaultLevel {
        let levels = connectedBridgeLevels.compactMap {
            NotificationCategory.DefaultLevel(z2mLogLevel: $0.level)
        }
        return levels.max()
            ?? NotificationCategory.DefaultLevel(z2mLogLevel: environment.selectedScope?.store.bridgeInfo?.logLevel ?? "")
            ?? .info
    }

    private var bridgeLogLevel: String? {
        switch effectiveLevel {
        case .error: "error"
        case .warning: "warning"
        case .info: "info"
        case .debug: "debug"
        case .optIn: nil
        }
    }

    private var visibleCategories: [NotificationCategory] {
        NotificationCategory.allCases.filter { category in
            switch category.defaultMinimumLogLevel {
            case .optIn: effectiveLevel == .debug
            default: category.defaultMinimumLogLevel <= effectiveLevel
            }
        }
    }

    private var visibleSections: [NotificationCategory.Section] {
        NotificationCategory.Section.allCases.filter { section in
            visibleCategories.contains(where: { $0.section == section })
        }
    }

    var body: some View {
        Form {
            ForEach(visibleSections, id: \.self) { section in
                Section(section.title) {
                    ForEach(visibleCategories.filter { $0.section == section }, id: \.self) { category in
                        Toggle(category.displayName, isOn: binding(for: category))
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

    private func binding(for category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: { environment.notificationPreferences.isEnabled(category, bridgeLogLevel: bridgeLogLevel) },
            set: { environment.notificationPreferences.setEnabled(category, enabled: $0, bridgeLogLevel: bridgeLogLevel) }
        )
    }
}

#Preview {
    NavigationStack {
        ActivityNotificationSettingsView()
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
