import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isActivityCenterEnabled = true
    @State private var tabSelection: AppTab = .home
    @State private var isCommandPalettePresented = false

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
        .modifier(MainTabNotificationPresentation())
        .sheet(item: Binding(
            get: { sceneNavigation.pendingLogSheet },
            set: { sceneNavigation.pendingLogSheet = $0 }
        )) { request in
            LogSheetHost(request: request)
        }
        .modifier(ActivityCenterSheetPresentation())
        .sheet(isPresented: $isCommandPalettePresented) {
            CommandPaletteView()
                .environment(environment)
        }
        .onAppear {
            if !AdaptiveLayout.isPad, sceneNavigation.selectedTab == .logs {
                sceneNavigation.isActivityCenterPresented = isActivityCenterEnabled
                sceneNavigation.selectedTab = tabSelection
            } else {
                tabSelection = sceneNavigation.selectedTab
            }
        }
        .onChange(of: tabSelection) { _, newValue in
            sceneNavigation.selectedTab = newValue
        }
        .onChange(of: sceneNavigation.selectedTab) { _, newValue in
            if !AdaptiveLayout.isPad, newValue == .logs {
                sceneNavigation.isActivityCenterPresented = isActivityCenterEnabled
                sceneNavigation.selectedTab = tabSelection
            } else {
                tabSelection = newValue
            }
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
                Tab(value: AppTab.devices) {
                    DeviceListView()
                } label: {
                    Label(AppTab.devices.title, symbol: AppTab.devices.symbol)
                }
                Tab(value: AppTab.groups) {
                    GroupListView()
                } label: {
                    Label(AppTab.groups.title, symbol: AppTab.groups.symbol)
                }
                if AdaptiveLayout.isPad {
                    Tab(value: AppTab.logs) {
                        NavigationStack {
                            LogsView()
                        }
                        .configuredTopScrollEdgeEffect()
                    } label: {
                        Label(AppTab.logs.title, symbol: AppTab.logs.symbol)
                    }
                    Tab(value: AppTab.networkMap) {
                        NetworkMapView()
                    } label: {
                        Label(AppTab.networkMap.title, symbol: AppTab.networkMap.symbol)
                    }
                }
                Tab(value: AppTab.settings) {
                    SettingsView()
                } label: {
                    Label(AppTab.settings.title, symbol: AppTab.settings.symbol)
                }
                .badge(anyBridgeNeedsRestart ? Text("!") : nil)
                Tab(value: AppTab.search, role: .search) {
                    GlobalSearchView()
                } label: {
                    Label(AppTab.search.title, symbol: AppTab.search.symbol)
                }
            }
            .modifier(SearchTabActivation())
        } else {
            TabView(selection: $tabSelection) {
                HomeView()
                    .tabItem { Label(AppTab.home.title, symbol: AppTab.home.symbol) }
                    .tag(AppTab.home)
                DeviceListView()
                    .tabItem { Label(AppTab.devices.title, symbol: AppTab.devices.symbol) }
                    .tag(AppTab.devices)
                GroupListView()
                    .tabItem { Label(AppTab.groups.title, symbol: AppTab.groups.symbol) }
                    .tag(AppTab.groups)
                if AdaptiveLayout.isPad {
                    NavigationStack {
                        LogsView()
                    }
                    .configuredTopScrollEdgeEffect()
                    .tabItem { Label(AppTab.logs.title, symbol: AppTab.logs.symbol) }
                    .tag(AppTab.logs)
                    NetworkMapView()
                        .tabItem { Label(AppTab.networkMap.title, symbol: AppTab.networkMap.symbol) }
                        .tag(AppTab.networkMap)
                }
                SettingsView()
                    .tabItem { Label(AppTab.settings.title, symbol: AppTab.settings.symbol) }
                    .tag(AppTab.settings)
                    .badge(anyBridgeNeedsRestart ? Text("!") : nil)
                GlobalSearchView()
                    .tabItem { Label(AppTab.search.title, symbol: AppTab.search.symbol) }
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
                    guard AdaptiveLayout.isPad else { return }
                } else if section == .logs, !AdaptiveLayout.isPad {
                    sceneNavigation.isActivityCenterPresented = isActivityCenterEnabled
                    return
                }
                tabSelection = section
            },
            showCommandPalette: {
                isCommandPalettePresented = true
            }
        )
    }

}

/// Uses the system-owned accessory host on iOS 26 and later, so notification
/// presentation follows the tab bar's Liquid Glass geometry and animations.
/// Earlier releases retain the established floating presentation.
private struct MainTabNotificationPresentation: ViewModifier {
    @AppStorage(ActivityCenterSettings.isEnabledStorageKey) private var isActivityCenterEnabled = true

    func body(content: Content) -> some View {
        if !isActivityCenterEnabled {
            content
        } else if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    ActivityTabBarAccessory()
                }
        } else {
            content.overlay(alignment: .bottom) {
                InAppNotificationOverlay()
                    .safeAreaPadding(.bottom)
                    .padding(.bottom, DesignTokens.Size.mainTabBarInset)
            }
        }
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
