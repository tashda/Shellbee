import SwiftUI

struct AppDeviceListSettingsView: View {
    @AppStorage(AppConfig.UX.recentDeviceWindowKey) private var recentDeviceWindowMinutes = Int(AppConfig.UX.recentDeviceWindowDefaultMinutes)

    var body: some View {
        Form {
            Section {
                Picker("Recently Added", selection: $recentDeviceWindowMinutes) {
                    ForEach(AppConfig.UX.recentDeviceWindowOptionsMinutes, id: \.self) { minutes in
                        Text(label(for: minutes)).tag(minutes)
                    }
                }
            } footer: {
                Text("How long a freshly paired device stays in Recently Added. Turn off Show Recents in the Devices sort menu to hide that section.")
            }
        }
        .navigationTitle("Devices")
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
        AppDeviceListSettingsView()
    }
}
