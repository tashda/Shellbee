import SwiftUI

struct AppGeneralView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink { AppAppearanceSettingsView() } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                NavigationLink { HomeCardsSettingsView() } label: {
                    Label("Home Cards", systemImage: "rectangle.grid.2x2.fill")
                }
            } header: {
                Text("Display")
            }

            Section {
                NavigationLink { AppDeviceListSettingsView() } label: {
                    Label("Devices", systemImage: "sensor.tag.radiowaves.forward.fill")
                }
                NavigationLink { AppConnectionSettingsView() } label: {
                    Label("Connection", systemImage: "arrow.trianglehead.2.clockwise")
                }
            } header: {
                Text("Behavior")
            }

            Section {
                NavigationLink { AppDiagnosticsSettingsView() } label: {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
                NavigationLink { AppAdvancedSettingsView() } label: {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
            } header: {
                Text("Support")
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppGeneralView()
    }
    .configuredTopScrollEdgeEffect()
}
