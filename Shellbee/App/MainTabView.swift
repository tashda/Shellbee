import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var tabSelection: AppTab = .home
    @State private var searchFocusRequest = AppSearchFocusRequest()

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
        .focusedSceneValue(\.appKeyboardActions, keyboardActions)
    }

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $tabSelection) {
                Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                    HomeView()
                }
                Tab("Devices", systemImage: "sensor.tag.radiowaves.forward.fill", value: AppTab.devices) {
                    DeviceListView(searchFocusRequest: searchFocusRequest)
                }
                Tab("Groups", systemImage: "square.on.square.fill", value: AppTab.groups) {
                    GroupListView(searchFocusRequest: searchFocusRequest)
                }
                if AdaptiveLayout.isPad {
                    Tab("Activity", systemImage: "list.bullet.rectangle", value: AppTab.logs) {
                        NavigationStack {
                            LogsView(searchFocusRequest: searchFocusRequest)
                        }
                    }
                    Tab("Network Map", systemImage: AppTab.networkMap.systemImage, value: AppTab.networkMap) {
                        networkMapPlaceholder
                    }
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
                DeviceListView(searchFocusRequest: searchFocusRequest)
                    .tabItem { Label("Devices", systemImage: "sensor.tag.radiowaves.forward.fill") }
                    .tag(AppTab.devices)
                GroupListView(searchFocusRequest: searchFocusRequest)
                    .tabItem { Label("Groups", systemImage: "square.on.square.fill") }
                    .tag(AppTab.groups)
                if AdaptiveLayout.isPad {
                    NavigationStack {
                        LogsView(searchFocusRequest: searchFocusRequest)
                    }
                    .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
                    .tag(AppTab.logs)
                    networkMapPlaceholder
                        .tabItem { Label("Network Map", systemImage: AppTab.networkMap.systemImage) }
                        .tag(AppTab.networkMap)
                }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
                    .badge(anyBridgeNeedsRestart ? Text("!") : nil)
            }
        }
    }

    private var keyboardActions: AppKeyboardActions {
        AppKeyboardActions(
            focusSearch: {
                searchFocusRequest.request(for: tabSelection)
            },
            selectSection: { section in
                guard AdaptiveLayout.isPad
                        || [.home, .devices, .groups, .settings].contains(section)
                else { return }
                tabSelection = section
            }
        )
    }

    private var networkMapPlaceholder: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Network Map",
                systemImage: AppTab.networkMap.systemImage,
                description: Text("Refresh the map to inspect the Zigbee topology.")
            )
            .navigationTitle("Network Map")
        }
    }
}

#Preview { MainTabView().environment(AppEnvironment()) }
