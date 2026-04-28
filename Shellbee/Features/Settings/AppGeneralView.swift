import SwiftUI

struct AppGeneralView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount: Int = HomeSettings.recentEventsCountDefault
    @AppStorage(ConnectionSessionController.maxReconnectAttemptsKey) private var maxReconnectAttempts: Int = ConnectionSessionController.defaultMaxReconnectAttempts
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled: Bool = false
    @State private var consent = CrashReportingConsent.shared

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.automatic)
            }

            Section {
                Picker("Recent Events", selection: $recentEventsCount) {
                    ForEach(HomeSettings.recentEventsOptions, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
            } header: {
                Text("Home")
            } footer: {
                Text("Number of recent events shown on the Home page.")
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
                Text("Crash reports contain the error and a short stack trace. Bridge URLs, tokens, and device names are redacted. When this is off, you'll still be asked before any crash is sent.")
            }

            Section {
                Toggle("Developer Mode", isOn: $developerModeEnabled)
            } header: {
                Text("Advanced")
            } footer: {
                Text("Exposes the MQTT Inspector and other power-user tools under a Developer section in Settings.")
            }
        }
        .navigationTitle("General")
    }
}

#Preview {
    NavigationStack {
        AppGeneralView()
    }
}
