import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @State private var tabSelection: AppTab = .home
    @State private var isCommandPalettePresented = false
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled = false

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
            get: { sceneNavigation.pendingLogSheet },
            set: { sceneNavigation.pendingLogSheet = $0 }
        )) { request in
            LogSheetHost(request: request)
        }
        .sheet(isPresented: $isCommandPalettePresented) {
            CommandPaletteView()
                .environment(environment)
        }
        .onAppear {
            tabSelection = sceneNavigation.selectedTab
        }
        .onChange(of: tabSelection) { _, newValue in
            sceneNavigation.selectedTab = newValue
        }
        .onChange(of: sceneNavigation.selectedTab) { _, newValue in
            tabSelection = newValue
        }
        .onChange(of: developerModeEnabled) { _, enabled in
            if !enabled, tabSelection == .networkMap { tabSelection = .home }
        }
        .focusedSceneValue(\.appKeyboardActions, keyboardActions)
    }

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $tabSelection) {
                Tab(value: AppTab.home) {
                    HomeView()
                } label: {
                    Label(AppTab.home.title, symbol: AppTab.home.symbol)
                }
                Tab("Devices", systemImage: "sensor.tag.radiowaves.forward.fill", value: AppTab.devices) {
                    DeviceListView()
                }
                Tab("Groups", systemImage: "square.on.square.fill", value: AppTab.groups) {
                    GroupListView()
                }
                if AdaptiveLayout.isPad {
                    Tab("Activity", systemImage: "list.bullet.rectangle", value: AppTab.logs) {
                        NavigationStack {
                            LogsView()
                        }
                        .configuredTopScrollEdgeEffect()
                    }
                    if developerModeEnabled {
                        Tab("Network Map", systemImage: AppTab.networkMap.systemImage, value: AppTab.networkMap) {
                            NetworkMapView()
                        }
                    }
                }
                Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsView()
                }
                .badge(anyBridgeNeedsRestart ? Text("!") : nil)
                Tab(AppTab.search.title, systemImage: AppTab.search.systemImage, value: AppTab.search, role: .search) {
                    GlobalSearchView()
                }
            }
            .modifier(SearchTabActivation())
        } else {
            TabView(selection: $tabSelection) {
                HomeView()
                    .tabItem { Label(AppTab.home.title, symbol: AppTab.home.symbol) }
                    .tag(AppTab.home)
                DeviceListView()
                    .tabItem { Label("Devices", systemImage: "sensor.tag.radiowaves.forward.fill") }
                    .tag(AppTab.devices)
                GroupListView()
                    .tabItem { Label("Groups", systemImage: "square.on.square.fill") }
                    .tag(AppTab.groups)
                if AdaptiveLayout.isPad {
                    NavigationStack {
                        LogsView()
                    }
                    .configuredTopScrollEdgeEffect()
                    .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
                    .tag(AppTab.logs)
                    if developerModeEnabled {
                        NetworkMapView()
                            .tabItem { Label("Network Map", systemImage: AppTab.networkMap.systemImage) }
                            .tag(AppTab.networkMap)
                    }
                }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
                    .badge(anyBridgeNeedsRestart ? Text("!") : nil)
                GlobalSearchView()
                    .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.systemImage) }
                    .tag(AppTab.search)
            }
        }
    }

    private var keyboardActions: AppKeyboardActions {
        AppKeyboardActions(
            focusSearch: {
                tabSelection = .search
            },
            selectSection: { section in
                if section == .networkMap {
                    guard AdaptiveLayout.isPad, developerModeEnabled else { return }
                } else if section == .logs {
                    guard AdaptiveLayout.isPad else { return }
                }
                tabSelection = section
            },
            showCommandPalette: {
                isCommandPalettePresented = true
            }
        )
    }

}

/// Shows the search tab as the separate search button at the end of the tab
/// bar and focuses the field as soon as it is selected, as in the system apps.
private struct SearchTabActivation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabViewSearchActivation(.searchTabSelection)
        } else {
            content
        }
    }
}

#Preview { MainTabView().environment(AppEnvironment()) }
