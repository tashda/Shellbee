import SwiftUI

/// iPad / regular-width shell. Adaptive shape based on width and section:
///
/// - **Wide iPad landscape sections** → 3-column:
///   sidebar + list + detail. Sidebar pinned inline. Tap a row, detail
///   fills the trailing column.
/// - **iPad portrait and iPhone** → 2-column: sidebar + section view.
///   Each section pushes detail within its own column (Reminders/Files
///   pattern).
///
/// `Logs` and `Device Library` are sidebar-only entries; the iPhone tab
/// bar declares its four tabs explicitly and never iterates
/// `AppTab.allCases`.
struct MainSplitView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: AppTab? = .home
    @State private var twoColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var threeColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedDeviceRoute: DeviceRoute?
    @State private var selectedGroupRoute: GroupRoute?
    @State private var selectedLogsPaneRoute: LogsPaneRoute?

    private var anyBridgeNeedsRestart: Bool {
        environment.registry.orderedSessions.contains { $0.store.bridgeInfo?.restartRequired == true }
    }

    private func usesThreeColumns(wideIPadLayout: Bool) -> Bool {
        guard wideIPadLayout else { return false }
        switch selection ?? .home {
        case .devices, .groups, .logs, .deviceLibrary, .settings: return true
        case .home: return false
        }
    }

    var body: some View {
        GeometryReader { geo in
            let wideIPadLayout = AdaptiveLayout.usesWideIPadLayout(in: geo.size)
            shell(
                usesThreeColumns: usesThreeColumns(wideIPadLayout: wideIPadLayout),
                usesWideHomeLayout: wideIPadLayout
            )
        }
        .overlay(alignment: .bottom) {
            InAppNotificationOverlay()
                .safeAreaPadding(.bottom)
        }
        .sheet(item: Binding(
            get: { environment.pendingLogSheet },
            set: { environment.pendingLogSheet = $0 }
        )) { request in
            LogSheetHost(request: request)
        }
        .onAppear { selection = environment.selectedTab }
        .onChange(of: selection) { _, newValue in
            if let newValue { environment.selectedTab = newValue }
        }
        .onChange(of: environment.selectedTab) { _, newValue in
            selection = newValue
        }
    }

    @ViewBuilder
    private func shell(usesThreeColumns: Bool, usesWideHomeLayout: Bool) -> some View {
        if usesThreeColumns {
            threeColumnShell
        } else {
            twoColumnShell(usesWideHomeLayout: usesWideHomeLayout)
        }
    }

    private func twoColumnShell(usesWideHomeLayout: Bool) -> some View {
        NavigationSplitView(columnVisibility: $twoColumnVisibility) {
            sidebar
                .navigationTitle("Shellbee")
        } detail: {
            twoColumnDetail(usesWideHomeLayout: usesWideHomeLayout)
        }
    }

    private var threeColumnShell: some View {
        // `.id(selection)` on the entire split rebuilds the whole
        // NavigationSplitView when the sidebar changes — that's the
        // only reliable way to clear the *implicit* navigation stack
        // in the detail column.
        //
        // The rebuild crossfades by default, which leaks the previous
        // selection's highlight across columns and triggers a transient
        // "navigationDestination outside a stack" warning while the old
        // shell tears down. `.transaction` strips animation off the
        // .id-driven rebuild so it's instant.
        NavigationSplitView(columnVisibility: $threeColumnVisibility) {
            sidebar
                .navigationTitle("Shellbee")
        } content: {
            threeColumnContent
                .navigationSplitViewColumnWidth(min: 360, ideal: 420)
                .environment(\.isSelectableListContext, true)
        } detail: {
            threeColumnDetail
        }
        .id(selection)
        .transaction(value: selection) { $0.animation = nil }
    }

    private var sidebar: some View {
        List(sidebarTabs, id: \.self, selection: $selection) { tab in
            sidebarRow(for: tab)
        }
        .listStyle(.sidebar)
    }

    private var sidebarTabs: [AppTab] {
        if AdaptiveLayout.isPad {
            AppTab.allCases
        } else {
            AppTab.allCases.filter { $0 != .deviceLibrary }
        }
    }

    @ViewBuilder
    private func sidebarRow(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            Label("Home", systemImage: "house.fill")
        case .devices:
            Label("Devices", systemImage: "sensor.tag.radiowaves.forward.fill")
        case .groups:
            Label("Groups", systemImage: "square.on.square.fill")
        case .logs:
            Label("Logs", systemImage: "list.bullet.rectangle")
        case .deviceLibrary:
            Label("Device Library", systemImage: "books.vertical.fill")
        case .settings:
            Label("Settings", systemImage: "gearshape.fill")
                .badge(anyBridgeNeedsRestart ? Text("!") : nil)
        }
    }

    /// 2-column detail: each section is self-contained with its own
    /// internal `NavigationStack`. Logs needs a stack supplied by the
    /// host since `LogsView` deliberately omits its own.
    @ViewBuilder
    private func twoColumnDetail(usesWideHomeLayout: Bool) -> some View {
        switch selection ?? .home {
        case .home:     HomeView(usesWideLayout: usesWideHomeLayout)
        case .devices:  DeviceListView()
        case .groups:   GroupListView()
        case .logs:
            NavigationStack {
                LogsView()
                    .navigationDestination(for: DeviceRoute.self) { route in
                        DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                    }
                    .navigationDestination(for: GroupRoute.self) { route in
                        GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                    }
            }
        case .deviceLibrary:
            NavigationStack {
                DocBrowserView()
            }
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private var threeColumnContent: some View {
        switch selection ?? .home {
        case .devices:
            DeviceListView(
                embedInNavigationStack: false,
                selection: $selectedDeviceRoute
            )
        case .groups:
            GroupListView(
                embedInNavigationStack: false,
                selection: $selectedGroupRoute
            )
        case .logs:
            LogsView(selection: $selectedLogsPaneRoute)
        case .deviceLibrary:
            DocBrowserView()
        case .settings:
            SettingsView(embedInNavigationStack: false)
        case .home:
            EmptyView()
        }
    }

    @ViewBuilder
    private var threeColumnDetail: some View {
        switch selection ?? .home {
        case .devices:
            if let route = selectedDeviceRoute {
                NavigationStack {
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    "Select a Device",
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    description: Text("Pick a device from the list to view its details.")
                )
            }
        case .groups:
            if let route = selectedGroupRoute {
                NavigationStack {
                    GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                        .navigationDestination(for: DeviceRoute.self) { deviceRoute in
                            DeviceDetailView(
                                bridgeID: deviceRoute.bridgeID,
                                device: deviceRoute.device
                            )
                        }
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    "Select a Group",
                    systemImage: "rectangle.3.group.fill",
                    description: Text("Pick a group from the list to view its members and scenes.")
                )
            }
        case .logs:
            if let route = selectedLogsPaneRoute {
                NavigationStack {
                    switch route {
                    case .activity(let logRoute):
                        LogDetailView(bridgeID: logRoute.bridgeID, entry: logRoute.entry)
                            .navigationDestination(for: DeviceRoute.self) { deviceRoute in
                                DeviceDetailView(
                                    bridgeID: deviceRoute.bridgeID,
                                    device: deviceRoute.device
                                )
                            }
                            .navigationDestination(for: GroupRoute.self) { groupRoute in
                                GroupDetailView(
                                    bridgeID: groupRoute.bridgeID,
                                    group: groupRoute.group
                                )
                            }
                    case .bridge(let logRoute):
                        BridgeLogDetailView(entry: logRoute.entry)
                    }
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    "Select a Log",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Pick a log entry from the list to view its details.")
                )
            }
        case .settings:
            ContentUnavailableView(
                "Select a Setting",
                systemImage: "gearshape.fill",
                description: Text("Pick a setting from the list to view its options.")
            )
        case .deviceLibrary:
            ContentUnavailableView(
                "Select a Device",
                systemImage: "books.vertical.fill",
                description: Text("Pick a device from the library to view its documentation.")
            )
        case .home:
            EmptyView()
        }
    }
}

#Preview { MainSplitView().environment(AppEnvironment()) }
