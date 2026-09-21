import SwiftUI

struct AppLiveActivitiesView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(ConnectionSessionController.permitJoinLiveActivityEnabledKey) private var permitJoinLiveActivityEnabled: Bool = true
    @AppStorage(ConnectionSessionController.touchlinkLiveActivityEnabledKey) private var touchlinkLiveActivityEnabled: Bool = true
    @AppStorage(ConnectionSessionController.otaLiveActivityEnabledKey) private var otaLiveActivityEnabled: Bool = true
    @AppStorage(ConnectionSessionController.otaScheduledLiveActivityEnabledKey) private var otaScheduledLiveActivityEnabled: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Permit Join", isOn: $permitJoinLiveActivityEnabled)
                Toggle("Touchlink", isOn: $touchlinkLiveActivityEnabled)
                Toggle("OTA Updates", isOn: $otaLiveActivityEnabled)
                Toggle("Scheduled OTAs", isOn: $otaScheduledLiveActivityEnabled)
                    .disabled(!otaLiveActivityEnabled)
            } header: {
                Text("Lock Screen and Dynamic Island")
            }
        }
        .navigationTitle("Live Activities")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: permitJoinLiveActivityEnabled) { _, _ in
            environment.refreshLiveActivityPreferences()
        }
        .onChange(of: touchlinkLiveActivityEnabled) { _, _ in
            environment.refreshLiveActivityPreferences()
        }
        .onChange(of: otaLiveActivityEnabled) { _, _ in
            environment.refreshLiveActivityPreferences()
        }
        .onChange(of: otaScheduledLiveActivityEnabled) { _, _ in
            environment.refreshLiveActivityPreferences()
        }
    }
}

#Preview {
    NavigationStack {
        AppLiveActivitiesView()
    }
    .configuredTopScrollEdgeEffect()
    .environment(AppEnvironment())
}
