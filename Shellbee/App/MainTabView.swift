import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var tabSelection: AppTab = .home

    var body: some View {
        TabView(selection: $tabSelection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Devices", systemImage: "sensor.tag.radiowaves.forward.fill", value: AppTab.devices) {
                DeviceListView()
            }
            Tab("Groups", systemImage: "square.on.square.fill", value: AppTab.groups) {
                GroupListView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
            .badge(environment.store.bridgeInfo?.restartRequired == true ? Text("!") : nil)
        }
        .overlay(alignment: .bottom) {
            InAppNotificationOverlay()
                .safeAreaPadding(.bottom)
                .padding(.bottom, 58)
        }
        .sheet(item: Binding(
            get: { environment.pendingLogSheet },
            set: { environment.pendingLogSheet = $0 }
        )) { request in
            LogSheetHost(request: request)
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

private struct LogSheetHost: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let request: LogSheetRequest

    var body: some View {
        NavigationStack {
            if request.isSingle,
               let id = request.entryIDs.first,
               let entry = environment.store.logEntries.first(where: { $0.id == id }) {
                LogDetailView(entry: entry)
                    .toolbar {
                        // Spacer visually separates the sheet's Done from
                        // LogDetailView's own formatter (curly-braces) button
                        // so they don't read as one grouped control.
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
            } else {
                LogsView(initialEntryFilter: Set(request.entryIDs))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
    }
}

#Preview { MainTabView().environment(AppEnvironment()) }
