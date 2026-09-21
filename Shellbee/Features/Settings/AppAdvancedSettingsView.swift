import SwiftUI

struct AppAdvancedSettingsView: View {
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle("Developer Mode", isOn: $developerModeEnabled)
            } footer: {
                Text("Adds power-user tools to Settings and Network Map on iPad.")
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppAdvancedSettingsView()
    }
}
