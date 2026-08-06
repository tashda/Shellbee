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
    @State private var selectedLogsPaneRoute: LogsPaneRoute?
    @State private var selectedSettingsRoute: SettingsWorkspaceRoute?
    @State private var selectedNetworkDeviceRoute: DeviceRoute?
    @State private var searchFocusRequest = AppSearchFocusRequest()
    @State private var isCommandPalettePresented = false
    @State private var deviceListViewModel = DeviceListViewModel()
    @State private var logsWorkspace = LogsWorkspaceState()
    @State private var groupsWorkspace = GroupsWorkspaceState()

    private var anyBridgeNeedsRestart: Bool {
        environment.registry.orderedSessions.contains { $0.store.bridgeInfo?.restartRequired == true }
    }

    private func usesThreeColumns(wideIPadLayout: Bool) -> Bool {
        guard wideIPadLayout else { return false }
        switch selection ?? .home {
        case .devices, .groups, .logs, .networkMap, .settings: return true
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
        .sheet(isPresented: $isCommandPalettePresented) {
            CommandPaletteView()
                .environment(environment)
        }
        .onAppear {
            selection = environment.selectedTab
            if let route = environment.pendingSettingsNavigation {
                selectedSettingsRoute = .bridgeOverview(route.bridgeID)
                environment.pendingSettingsNavigation = nil
            }
        }
        .onChange(of: selection) { _, newValue in
            if let newValue { environment.selectedTab = newValue }
        }
        .onChange(of: environment.selectedTab) { _, newValue in
            selection = newValue
        }
        .onChange(of: environment.pendingSettingsNavigation) { _, route in
            guard let route else { return }
            selectedSettingsRoute = .bridgeOverview(route.bridgeID)
            environment.pendingSettingsNavigation = nil
        }
        .onChange(of: logsWorkspace.mode) { _, _ in
            selectedLogsPaneRoute = nil
        }
        .onChange(of: environment.allGroups) { _, groups in
            groupsWorkspace.reconcile(groups: groups, devices: environment.allDevices)
        }
        .onChange(of: environment.allDevices) { _, devices in
            groupsWorkspace.reconcile(groups: environment.allGroups, devices: devices)
        }
        .focusedSceneValue(\.appKeyboardActions, keyboardActions)
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
        List(selection: $selection) {
            Section("Shellbee") {
                ForEach(sidebarTabs, id: \.self) { tab in
                    sidebarRow(for: tab)
                }
            }
            if selection == .devices {
                DeviceWorkspaceFilters(viewModel: deviceListViewModel)
            }
            if selection == .logs {
                ActivityWorkspaceFilters(workspace: logsWorkspace)
            }
            if selection == .groups {
                GroupWorkspaceSidebarSection(workspace: groupsWorkspace)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            if selection == .groups {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private var sidebarTabs: [AppTab] { AppTab.allCases }

    private func sidebarRow(for tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
            .badge(tab == .settings && anyBridgeNeedsRestart ? Text("!") : nil)
    }

    /// 2-column detail: each section is self-contained with its own
    /// internal `NavigationStack`. Logs needs a stack supplied by the
    /// host since `LogsView` deliberately omits its own.
    @ViewBuilder
    private func twoColumnDetail(usesWideHomeLayout: Bool) -> some View {
        switch selection ?? .home {
        case .home:     HomeView(usesWideLayout: usesWideHomeLayout)
        case .devices:
            DeviceListView(
                searchFocusRequest: searchFocusRequest,
                viewModel: deviceListViewModel
            )
        case .groups:   GroupListView(searchFocusRequest: searchFocusRequest)
        case .logs:
            NavigationStack {
                LogsView(
                    searchFocusRequest: searchFocusRequest,
                    workspace: logsWorkspace
                )
                    .navigationDestination(for: DeviceRoute.self) { route in
                        DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                    }
                    .navigationDestination(for: GroupRoute.self) { route in
                        GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                    }
            }
        case .networkMap: NetworkMapView()
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private var threeColumnContent: some View {
        switch selection ?? .home {
        case .devices:
            DeviceListView(
                embedInNavigationStack: false,
                selection: $selectedDeviceRoute,
                searchFocusRequest: searchFocusRequest,
                viewModel: deviceListViewModel
            )
        case .groups:
            if let route = groupsWorkspace.selectedGroup {
                NavigationStack {
                    GroupDetailView(
                        bridgeID: route.bridgeID,
                        group: route.group,
                        memberSelection: groupMemberSelection
                    )
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    "Select a Group",
                    systemImage: "rectangle.3.group.fill",
                    description: Text("Pick a group from the sidebar to view its controls, members, and scenes.")
                )
            }
        case .logs:
            LogsView(
                selection: $selectedLogsPaneRoute,
                searchFocusRequest: searchFocusRequest,
                workspace: logsWorkspace
            )
        case .networkMap:
            NetworkMapView(
                embedInNavigationStack: false,
                selection: $selectedNetworkDeviceRoute
            )
        case .settings:
            SettingsWorkspaceList(selection: $selectedSettingsRoute)
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
            if let route = groupsWorkspace.selectedMember {
                NavigationStack {
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    groupsWorkspace.selectedGroup == nil ? "Select a Group" : "Select a Member",
                    systemImage: groupsWorkspace.selectedGroup == nil
                        ? "rectangle.3.group.fill"
                        : "sensor.tag.radiowaves.forward.fill",
                    description: Text(
                        groupsWorkspace.selectedGroup == nil
                            ? "Pick a group from the sidebar to begin."
                            : "Pick a member to view its device details."
                    )
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
            if let route = selectedSettingsRoute {
                NavigationStack {
                    SettingsWorkspaceDestinationView(route: route)
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    "Select a Setting",
                    systemImage: "gearshape.fill",
                    description: Text("Pick a setting from the list to view its options.")
                )
            }
        case .networkMap:
            if let route = selectedNetworkDeviceRoute {
                NavigationStack {
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .id(route)
            } else {
                ContentUnavailableView(
                    "Select a Device",
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    description: Text("Pick a node from the map to view its device details.")
                )
            }
        case .home:
            EmptyView()
        }
    }

    private var keyboardActions: AppKeyboardActions {
        AppKeyboardActions(
            focusSearch: {
                searchFocusRequest.request(for: selection ?? .home)
            },
            selectSection: { section in
                selection = section
            },
            showCommandPalette: {
                isCommandPalettePresented = true
            }
        )
    }

    private var groupMemberSelection: Binding<DeviceRoute?> {
        Binding(
            get: { groupsWorkspace.selectedMember },
            set: { groupsWorkspace.selectMember($0) }
        )
    }
}

#Preview { MainSplitView().environment(AppEnvironment()) }
