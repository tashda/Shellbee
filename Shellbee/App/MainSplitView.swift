import SwiftUI

/// iPad / regular-width shell. Adaptive shape based on width and section:
///
/// - **Devices / Groups in landscape** (≥ ~1000pt) → 3-column:
///   sidebar + list + detail. Sidebar pinned inline. Tap a row, detail
///   fills the trailing column.
/// - **Everything else** → 2-column: sidebar + section view. Devices
///   and Groups push detail within their own column (Reminders/Files
///   pattern). Logs is always 2-column — its rows use closure-based
///   `NavigationLink`, which can't auto-route to a detail column.
///
/// `Logs` is a sidebar-only entry; the iPhone tab bar hardcodes the
/// other four tabs and never iterates `AppTab.allCases`, so it doesn't
/// pick up the new case.
struct MainSplitView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: AppTab? = .home
    @State private var twoColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var threeColumnVisibility: NavigationSplitViewVisibility = .all

    /// Width above which we render three columns for Devices / Groups.
    /// Every iPad in landscape is wider than this; every iPad in portrait
    /// is narrower.
    private static let threeColumnThreshold: CGFloat = 1000

    private var anyBridgeNeedsRestart: Bool {
        environment.registry.orderedSessions.contains { $0.store.bridgeInfo?.restartRequired == true }
    }

    private func usesThreeColumns(width: CGFloat) -> Bool {
        guard width >= Self.threeColumnThreshold else { return false }
        switch selection ?? .home {
        case .devices, .groups: return true
        case .home, .logs, .settings: return false
        }
    }

    var body: some View {
        GeometryReader { geo in
            shell(usesThreeColumns: usesThreeColumns(width: geo.size.width))
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
    private func shell(usesThreeColumns: Bool) -> some View {
        if usesThreeColumns {
            threeColumnShell
        } else {
            twoColumnShell
        }
    }

    private var twoColumnShell: some View {
        NavigationSplitView(columnVisibility: $twoColumnVisibility) {
            sidebar
                .navigationTitle("Shellbee")
        } detail: {
            twoColumnDetail
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
        List(AppTab.allCases, id: \.self, selection: $selection) { tab in
            sidebarRow(for: tab)
        }
        .listStyle(.sidebar)
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
        case .settings:
            Label("Settings", systemImage: "gearshape.fill")
                .badge(anyBridgeNeedsRestart ? Text("!") : nil)
        }
    }

    /// 2-column detail: each section is self-contained with its own
    /// internal `NavigationStack`. Logs needs a stack supplied by the
    /// host since `LogsView` deliberately omits its own.
    @ViewBuilder
    private var twoColumnDetail: some View {
        switch selection ?? .home {
        case .home:     HomeView()
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
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private var threeColumnContent: some View {
        switch selection ?? .home {
        case .devices:  DeviceListView(embedInNavigationStack: false)
        case .groups:   GroupListView(embedInNavigationStack: false)
        case .home, .logs, .settings:
            EmptyView()
        }
    }

    @ViewBuilder
    private var threeColumnDetail: some View {
        switch selection ?? .home {
        case .devices:
            ContentUnavailableView(
                "Select a Device",
                systemImage: "sensor.tag.radiowaves.forward.fill",
                description: Text("Pick a device from the list to view its details.")
            )
        case .groups:
            ContentUnavailableView(
                "Select a Group",
                systemImage: "rectangle.3.group.fill",
                description: Text("Pick a group from the list to view its members and scenes.")
            )
        case .home, .logs, .settings:
            EmptyView()
        }
    }
}

#Preview { MainSplitView().environment(AppEnvironment()) }
