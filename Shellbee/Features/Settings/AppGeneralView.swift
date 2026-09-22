import SwiftUI

struct AppGeneralView: View {
    @AppStorage(AppConfig.UX.recentDeviceWindowKey) private var recentDeviceWindowMinutes = Int(AppConfig.UX.recentDeviceWindowDefaultMinutes)
    @AppStorage(ConnectionSessionController.maxReconnectAttemptsKey) private var maxReconnectAttempts = ConnectionSessionController.defaultMaxReconnectAttempts
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled = false
    @State private var consent = CrashReportingConsent.shared

    var body: some View {
        Form {
            Section {
                Picker("Recently Added", selection: $recentDeviceWindowMinutes) {
                    ForEach(AppConfig.UX.recentDeviceWindowOptionsMinutes, id: \.self) { minutes in
                        Text(label(for: minutes)).tag(minutes)
                    }
                }
            } header: {
                Text("Devices")
            } footer: {
                Text("How long a freshly paired device stays in Recently Added. Turn off Show Recents in the Devices sort menu to hide that section.")
            }

            Section {
                InlineIntField(
                    "Reconnect Limit",
                    value: $maxReconnectAttempts,
                    unit: "attempts",
                    range: ConnectionSessionController.maxReconnectAttemptsRange
                )
            } header: {
                Text("Connection")
            } footer: {
                Text("How many times Shellbee retries before giving up. Opening the app always tries again.")
            }

            Section {
                Toggle("Automatically Share Crash Reports", isOn: Binding(
                    get: { consent.alwaysShare },
                    set: { consent.alwaysShare = $0 }
                ))
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("When off, Shellbee asks before sending a crash report.")
            }

            Section {
                Toggle("Developer Mode", isOn: $developerModeEnabled)
            } header: {
                Text("Advanced")
            } footer: {
                Text("Adds power-user tools to Settings and Network Map on iPad.")
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(for minutes: Int) -> String {
        switch minutes {
        case 1..<60: "\(minutes) min"
        case 60: "1 hour"
        case 120: "2 hours"
        case 240: "4 hours"
        case 1440: "1 day"
        default: "\(minutes / 60) hours"
        }
    }
}

#Preview {
    NavigationStack {
        AppGeneralView()
    }
}
