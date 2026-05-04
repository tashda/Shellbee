import SwiftUI

struct AppGeneralView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(BridgeGradientMode.storageKey) private var bridgeGradientModeRaw: String = BridgeGradientMode.default.rawValue
    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount: Int = HomeSettings.recentEventsCountDefault
    @AppStorage(AppConfig.UX.recentDeviceWindowKey) private var recentDeviceWindowMinutes: Int = Int(AppConfig.UX.recentDeviceWindowDefaultMinutes)
    @AppStorage(ConnectionSessionController.maxReconnectAttemptsKey) private var maxReconnectAttempts: Int = ConnectionSessionController.defaultMaxReconnectAttempts
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled: Bool = false
    @State private var consent = CrashReportingConsent.shared

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearanceMode) {
                    Text("System").tag(AppearanceMode.system)
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                }
                .pickerStyle(.automatic)

                Picker("Bridge Indicator", selection: $bridgeGradientModeRaw) {
                    ForEach(BridgeGradientMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.automatic)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Bridge Indicator paints a thin colored line on the leading edge of every device, group, and log row so each bridge's content is easy to identify at a glance. Automatic shows the line only when more than one bridge is connected.")
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
                Picker("Recently Added Window", selection: $recentDeviceWindowMinutes) {
                    ForEach(AppConfig.UX.recentDeviceWindowOptionsMinutes, id: \.self) { minutes in
                        Text(label(forMinutes: minutes)).tag(minutes)
                    }
                }
            } header: {
                Text("Devices")
            } footer: {
                Text("How long a freshly-paired device stays in the “Recently Added” section of the device list. To hide the section entirely, toggle “Show Recents” off in the Sort menu on the Devices tab.")
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

    private func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 1..<60: return "\(minutes) min"
        case 60: return "1 hour"
        case 120: return "2 hours"
        case 240: return "4 hours"
        case 1440: return "1 day"
        default:
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
    }
}

#Preview {
    NavigationStack {
        AppGeneralView()
    }
}
