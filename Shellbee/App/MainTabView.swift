import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var tabSelection: AppTab = .home

    init() {
        // iOS 26 has the new floating glass tab bar from the Tab { } builder,
        // which we don't want to disturb. On iOS 17/18 the classic UITabBar
        // goes transparent at the scroll edge by default; force opaque so it
        // always shows the system fill instead of fading into content.
        if #unavailable(iOS 26.0) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        tabContent
        .overlay(alignment: .bottom) {
            InAppNotificationOverlay()
                .safeAreaPadding(.bottom)
                .padding(.bottom, DesignTokens.Size.mainTabBarInset)
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

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 18.0, *) {
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
        } else {
            TabView(selection: $tabSelection) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)
                DeviceListView()
                    .tabItem { Label("Devices", systemImage: "sensor.tag.radiowaves.forward.fill") }
                    .tag(AppTab.devices)
                GroupListView()
                    .tabItem { Label("Groups", systemImage: "square.on.square.fill") }
                    .tag(AppTab.groups)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
                    .badge(environment.store.bridgeInfo?.restartRequired == true ? Text("!") : nil)
            }
        }
    }
}

private struct LogSheetHost: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let request: LogSheetRequest

    var body: some View {
        if request.isSingle,
           let id = request.entryIDs.first,
           let entry = environment.store.logEntries.first(where: { $0.id == id }) {
            NavigationStack {
                LogDetailView(entry: entry, doneAction: { dismiss() })
            }
        } else {
            LogsView(
                initialEntryFilter: Set(request.entryIDs),
                notificationSheetStyle: true,
                onDone: { dismiss() }
            )
        }
    }
}

#Preview { MainTabView().environment(AppEnvironment()) }
