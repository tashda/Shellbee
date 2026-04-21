import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var tabSelection: AppTab = .home

    var body: some View {
        TabView(selection: $tabSelection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Devices", systemImage: "cpu", value: AppTab.devices) {
                DeviceListView()
            }
            Tab("Groups", systemImage: "rectangle.3.group.fill", value: AppTab.groups) {
                GroupListView()
            }
            Tab("Settings", systemImage: "gearshape.2.fill", value: AppTab.settings) {
                SettingsView()
            }
            .badge(environment.store.bridgeInfo?.restartRequired == true ? Text("!") : nil)
        }
        .onAppear {
            tabSelection = environment.selectedTab
        }
        .onChange(of: tabSelection) { _, newValue in
            environment.selectedTab = newValue
        }
        .onChange(of: environment.selectedTab) { _, newValue in
            tabSelection = newValue
        }
    }
}

#Preview { MainTabView().environment(AppEnvironment()) }
