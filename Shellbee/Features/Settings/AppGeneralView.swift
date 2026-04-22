import SwiftUI

struct AppGeneralView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
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
                Toggle("Automatically share crash reports", isOn: Binding(
                    get: { consent.alwaysShare },
                    set: { consent.alwaysShare = $0 }
                ))
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Crash reports contain the error and a short stack trace. Bridge URLs, tokens, and device names are redacted. When this is off, you'll still be asked before any crash is sent.")
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
