import SwiftUI

struct AppDiagnosticsSettingsView: View {
    @State private var consent = CrashReportingConsent.shared

    var body: some View {
        Form {
            Section {
                Toggle("Automatically Share Crash Reports", isOn: Binding(
                    get: { consent.alwaysShare },
                    set: { consent.alwaysShare = $0 }
                ))
            } footer: {
                Text("When off, Shellbee asks before sending a crash report.")
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppDiagnosticsSettingsView()
    }
}
