import SwiftUI

struct AppNotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    /// Connected bridges paired with their reported Z2M log level. Drives
    /// both the per-bridge rows in the About section and the visibility of
    /// notification categories below.
    private var connectedBridgeLevels: [(session: BridgeSession, level: String)] {
        environment.registry.orderedSessions
            .filter(\.isConnected)
            .map { ($0, $0.store.bridgeInfo?.logLevel ?? "info") }
    }

    /// The most verbose log level across every connected bridge — used to
    /// decide which notification categories to surface, so a category that
    /// any bridge could emit stays visible/configurable.
    private var effectiveLevel: NotificationCategory.DefaultLevel {
        let levels = connectedBridgeLevels.compactMap {
            NotificationCategory.DefaultLevel(z2mLogLevel: $0.level)
        }
        return levels.max() ?? NotificationCategory.DefaultLevel(z2mLogLevel: environment.selectedScope?.store.bridgeInfo?.logLevel ?? "") ?? .info
    }

    /// Representative bridge log level for `NotificationPreferences` reads
    /// and writes. Mirrors `effectiveLevel` so default-baseline computation
    /// matches the categories the user can see.
    private var bridgeLogLevel: String? {
        switch effectiveLevel {
        case .error: return "error"
        case .warning: return "warning"
        case .info: return "info"
        case .debug: return "debug"
        case .optIn: return nil
        }
    }

    private var visibleCategories: [NotificationCategory] {
        let currentLevel = effectiveLevel
        return NotificationCategory.allCases.filter { category in
            switch category.defaultMinimumLogLevel {
            case .optIn:
                // Surface opt-in categories only when the bridge is in its
                // most verbose mode — otherwise the user has no signal this
                // category exists.
                return currentLevel == .debug
            default:
                return category.defaultMinimumLogLevel <= currentLevel
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
            aboutSection

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

    @ViewBuilder
    private var aboutSection: some View {
        let bridges = connectedBridgeLevels
        Section {
            if bridges.count >= 2 {
                ForEach(bridges, id: \.session.bridgeID) { entry in
                    LabeledContent(entry.session.displayName, value: entry.level.capitalized)
                }
            } else {
                let level = bridges.first?.level ?? "info"
                LabeledContent("Bridge Log Level", value: level.capitalized)
            }
        } header: {
            if bridges.count >= 2 {
                Text("Bridge Log Level")
            }
        } footer: {
            Text("Change in Settings → Logging.")
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
