import SwiftUI

struct AppLiveActivitiesView: View {
    @AppStorage(ConnectionSessionController.connectionLiveActivityEnabledKey) private var connectionLiveActivityEnabled: Bool = true
    @AppStorage(ConnectionSessionController.otaLiveActivityEnabledKey) private var otaLiveActivityEnabled: Bool = true
    @AppStorage(ConnectionSessionController.otaScheduledLiveActivityEnabledKey) private var otaScheduledLiveActivityEnabled: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Connection", isOn: $connectionLiveActivityEnabled)
                Toggle("OTA Updates", isOn: $otaLiveActivityEnabled)
            } header: {
                Text("On Lock Screen")
            } footer: {
                Text("Show progress on the Lock Screen and Dynamic Island.")
            }

            Section {
                Toggle("Scheduled OTAs", isOn: $otaScheduledLiveActivityEnabled)
                    .disabled(!otaLiveActivityEnabled)
            } footer: {
                Text("Off by default — scheduled updates can sit pending for hours waiting for the device to wake up.")
            }
        }
        .navigationTitle("Live Activities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppLiveActivitiesView()
    }
}
