import SwiftUI

struct AppNotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    private var bridgeLogLevel: String? {
        environment.store.bridgeInfo?.logLevel
    }

    private var displayedLevel: String {
        bridgeLogLevel ?? "info"
    }

    private var visibleCategories: [NotificationCategory] {
        let currentLevel = NotificationCategory.DefaultLevel(z2mLogLevel: displayedLevel) ?? .info
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
        Section {
            NavigationLink {
                MainSettingsView(highlight: .logLevel)
            } label: {
                LabeledContent("Bridge Log Level", value: displayedLevel.capitalized)
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
