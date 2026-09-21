import SwiftUI

struct NetworkMapView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    var embedInNavigationStack = true
    private let selection: Binding<DeviceRoute?>?
    private let externalFilters: Binding<Set<NetworkMapFilter>>?
    private let externalBridgeSelection: Binding<UUID?>?
    private let initialBridgeID: UUID?

    @State private var internalSelectedBridgeID: UUID?
    @State private var internalFilters: Set<NetworkMapFilter> = []
    @State private var autoOpenedDeviceRoute: DeviceRoute?
    @State private var deviceViewModel = DeviceListViewModel()
    @State private var deviceToRename: BridgeBoundDevice?
    @State private var deviceToRemove: BridgeBoundDevice?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    @State private var zoomController = NetworkMapZoomController()

    init(
        embedInNavigationStack: Bool = true,
        selection: Binding<DeviceRoute?>? = nil,
        filters: Binding<Set<NetworkMapFilter>>? = nil,
        bridgeSelection: Binding<UUID?>? = nil,
        initialBridgeID: UUID? = nil
    ) {
        self.embedInNavigationStack = embedInNavigationStack
        self.selection = selection
        self.externalFilters = filters
        self.externalBridgeSelection = bridgeSelection
        self.initialBridgeID = initialBridgeID
    }

    /// A host embedding the map inside its own sidebar (see `MainSplitView`)
    /// can pass its own filter state here so a sidebar filter section and
    /// this view's canvas share one Set instead of drifting apart.
    private var filters: Binding<Set<NetworkMapFilter>> {
        externalFilters ?? $internalFilters
    }

    private var bridgeSelection: Binding<UUID?> {
        externalBridgeSelection ?? $internalSelectedBridgeID
    }

    private var selectedBridgeID: UUID? {
        bridgeSelection.wrappedValue
    }

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    private var selectedSession: BridgeSession? {
        guard let selectedBridgeID else { return nil }
        return environment.registry.session(for: selectedBridgeID)
    }

    var body: some View {
        SwiftUI.Group {
            if embedInNavigationStack {
                NavigationStack { content }
            } else {
                content
            }
        }
        .sheet(item: $deviceToRename) { bound in
            RenameDeviceSheet(device: bound.device) { newName, updateHA in
                deviceViewModel.renameDevice(
                    bound.device,
                    to: newName,
                    homeassistantRename: updateHA,
                    environment: environment,
                    bridgeID: bound.bridgeID
                )
            }
        }
        .sheet(item: $deviceToRemove) { bound in
            RemoveDeviceSheet(device: bound.device) { force, block in
                deviceViewModel.removeDevice(
                    bound.device,
                    force: force,
                    block: block,
                    environment: environment,
                    bridgeID: bound.bridgeID
                )
            }
        }
        .alert(
            pendingDeviceAlert?.title ?? "",
            isPresented: Binding(
                get: { pendingDeviceAlert != nil },
                set: { if !$0 { pendingDeviceAlert = nil } }
            ),
            presenting: pendingDeviceAlert
        ) { alert in
            Button(alert.confirmTitle, role: alert.role) {
                guard let selectedBridgeID else { return }
                switch alert {
                case .reconfigure(let device):
                    deviceViewModel.reconfigureDevice(device, environment: environment, bridgeID: selectedBridgeID)
                case .interview(let device):
                    deviceViewModel.interviewDevice(device, environment: environment, bridgeID: selectedBridgeID)
                }
                pendingDeviceAlert = nil
            }
            Button("Cancel", role: .cancel) { pendingDeviceAlert = nil }
        } message: { alert in
            Text(alert.message)
        }
        .onAppear { establishSelectedBridge() }
        .onChange(of: sceneNavigation.pendingNetworkMapBridgeID) { _, _ in
            consumePendingNavigation()
        }
        .onChange(of: selectedBridgeID) { _, _ in
            routeBinding.wrappedValue = nil
            sceneNavigation.selectedBridgeID = selectedBridgeID
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if let session = selectedSession,
               session.store.networkTopology == nil,
               session.store.networkMapRefreshPhase != .idle {
                refreshProgress(for: session, fillsViewport: true)
            } else if let session = selectedSession,
                      let topology = session.store.networkTopology {
                ZStack {
                    NetworkMapCanvasView(
                        bridgeID: session.bridgeID,
                        topology: topology,
                        filters: filters,
                        selection: routeBinding,
                        deviceViewModel: deviceViewModel,
                        onRename: { deviceToRename = $0 },
                        onRemove: { deviceToRemove = $0 },
                        onPendingAlert: { alert, _ in pendingDeviceAlert = alert },
                        onMapRendered: {
                            session.store.finishNetworkMapRefreshPresentation()
                        },
                        zoomController: zoomController
                    )
                    .id(session.bridgeID)

                    if session.store.networkMapRefreshPhase != .idle {
                        Color.black.opacity(0.06)
                            .ignoresSafeArea()
                        refreshProgress(for: session, fillsViewport: false)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    lastUpdatedLabel(session.store.networkMapLastUpdated)
                        .padding(DesignTokens.Spacing.md)
                }
            } else if let session = selectedSession,
                      session.store.networkMapRefreshPhase != .idle {
                refreshProgress(for: session, fillsViewport: true)
            } else {
                ContentUnavailableView(
                    "No Network Map",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Refresh to fetch the Zigbee topology. This can take up to a minute on a busy network.")
                )
                .overlay(alignment: .bottom) {
                    Button("Refresh", action: { refresh() })
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedSession == nil || selectedSession?.store.networkMapIsRefreshing == true)
                        .padding(DesignTokens.Spacing.xl)
                }
            }
        }
        .navigationTitle("Network Map")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $autoOpenedDeviceRoute) { route in
            DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { zoomController.zoomOut() } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .accessibilityLabel("Zoom Out")
                Button { zoomController.fit() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("Fit Network Map")
                Button { zoomController.zoomIn() } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .accessibilityLabel("Zoom In")
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                OpenInNewWindowButton(destination: .networkMap(bridgeID: selectedBridgeID))
                refreshToolbarItem
            }
        }
        .configuredTopScrollEdgeEffect()
    }

    @ViewBuilder
    private var refreshToolbarItem: some View {
        if connectedSessions.count > 1 {
            Menu {
                ForEach(connectedSessions, id: \.bridgeID) { session in
                    Button {
                        refresh(bridgeID: session.bridgeID)
                    } label: {
                        Label {
                            Text(session.displayName)
                        } icon: {
                            if session.bridgeID == selectedBridgeID {
                                Image(systemName: "checkmark.circle")
                            } else {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                            }
                        }
                    }
                }
            } label: {
                refreshToolbarIcon
            }
            .accessibilityLabel("Refresh Network Map")
        } else {
            Button(action: { refresh() }) {
                refreshToolbarIcon
            }
            .accessibilityLabel("Refresh Network Map")
        }
    }

    private var routeBinding: Binding<DeviceRoute?> {
        selection ?? Binding(
            get: { autoOpenedDeviceRoute },
            set: { autoOpenedDeviceRoute = $0 }
        )
    }

    private func refresh(bridgeID: UUID? = nil) {
        guard let bridgeID = bridgeID ?? selectedBridgeID,
              let session = environment.registry.session(for: bridgeID),
              !session.store.networkMapIsRefreshing
        else { return }
        // Refresh state belongs to the bridge store, not this view. The
        // request therefore continues if the user changes sidebar sections.
        session.store.beginNetworkMapRefresh()
        environment.send(
            bridge: session.bridgeID,
            topic: Z2MTopics.Request.networkMap,
            payload: .object([
                "type": .string("raw"),
                "routes": .bool(false)
            ])
        )
        if sceneNavigation.pendingNetworkMapRefreshBridgeID == bridgeID {
            sceneNavigation.pendingNetworkMapRefreshBridgeID = nil
        }
    }

    private func establishSelectedBridge() {
        consumePendingNavigation()
        if selectedBridgeID == nil {
            bridgeSelection.wrappedValue = initialBridgeID ?? sceneNavigation.selectedBridgeID
                ?? environment.registry.primaryBridgeID
                ?? connectedSessions.first?.bridgeID
        }
        if sceneNavigation.pendingNetworkMapRefreshBridgeID == selectedBridgeID {
            refresh()
        }
    }

    private func consumePendingNavigation() {
        guard let bridgeID = sceneNavigation.pendingNetworkMapBridgeID,
              environment.registry.session(for: bridgeID) != nil
        else { return }
        bridgeSelection.wrappedValue = bridgeID
        sceneNavigation.pendingNetworkMapBridgeID = nil
        if sceneNavigation.pendingNetworkMapRefreshBridgeID == bridgeID {
            refresh()
        }
    }

    private func lastUpdatedLabel(_ date: Date?) -> some View {
        Text(date.map { "Last updated \($0.formatted(.relative(presentation: .named)))" } ?? "Not updated")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(.thinMaterial, in: Capsule())
    }

    private func refreshProgress(for session: BridgeSession, fillsViewport: Bool) -> some View {
        NetworkMapRefreshProgressView(
            bridgeName: session.displayName,
            phase: session.store.networkMapRefreshPhase,
            startedAt: session.store.networkMapRefreshStartedAt,
            totalDevices: session.store.networkMapRefreshTotalDevices,
            reportedDevices: 0,
            fillsViewport: fillsViewport
        )
    }

    private var refreshToolbarIcon: some View {
        Image(systemName: "arrow.clockwise")
    }
}

#Preview {
    NetworkMapView()
        .environment(AppEnvironment())
}
