import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var tabSelection: AppTab = .home

    /// Phase 2 multi-bridge: the Settings tab badge surfaces when any
    /// connected bridge has pending config that needs a restart. Single-
    /// bridge collapses to one match.
    private var anyBridgeNeedsRestart: Bool {
        environment.registry.orderedSessions.contains { $0.store.bridgeInfo?.restartRequired == true }
    }

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
                .badge(anyBridgeNeedsRestart ? Text("!") : nil)
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
                    .badge(anyBridgeNeedsRestart ? Text("!") : nil)
            }
        }
    }
}

private struct LogSheetHost: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let request: LogSheetRequest

    /// Phase 1 multi-bridge: the request carries log entry ids only — find
    /// which bridge owns the entry by scanning every connected session and
    /// route detail there. Falls through to the merged Logs view when more
    /// than one entry is requested or none can be located.
    private var singleResolved: (UUID, LogEntry)? {
        guard request.isSingle, let id = request.entryIDs.first else { return nil }
        for session in environment.registry.orderedSessions {
            if let entry = session.store.logEntries.first(where: { $0.id == id }) {
                return (session.bridgeID, entry)
            }
        }
        return nil
    }

    var body: some View {
        if let (bridgeID, entry) = singleResolved {
            NavigationStack {
                LogDetailView(bridgeID: bridgeID, entry: entry, doneAction: { dismiss() })
                    .navigationDestination(for: DeviceRoute.self) { route in
                        DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                    }
                    .navigationDestination(for: GroupRoute.self) { route in
                        GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                    }
            }
        } else {
            NavigationStack {
                LogsView(
                    initialEntryFilter: Set(request.entryIDs),
                    notificationSheetStyle: true,
                    onDone: { dismiss() }
                )
                .navigationDestination(for: DeviceRoute.self) { route in
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .navigationDestination(for: GroupRoute.self) { route in
                    GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                }
            }
        }
    }
}

#Preview { MainTabView().environment(AppEnvironment()) }
