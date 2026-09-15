import SwiftUI

struct NetworkMapView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    var embedInNavigationStack = true
    private let selection: Binding<DeviceRoute?>?
    private let externalFilters: Binding<Set<NetworkMapFilter>>?
    private let initialBridgeID: UUID?

    @State private var selectedBridgeID: UUID?
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
        initialBridgeID: UUID? = nil
    ) {
        self.embedInNavigationStack = embedInNavigationStack
        self.selection = selection
        self.externalFilters = filters
        self.initialBridgeID = initialBridgeID
    }

    /// A host embedding the map inside its own sidebar (see `MainSplitView`)
    /// can pass its own filter state here so a sidebar filter section and
    /// this view's canvas share one Set instead of drifting apart.
    private var filters: Binding<Set<NetworkMapFilter>> {
        externalFilters ?? $internalFilters
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
               let topology = session.store.networkTopology {
                NetworkMapCanvasView(
                    bridgeID: session.bridgeID,
                    topology: topology,
                    filters: filters,
                    selection: routeBinding,
                    deviceViewModel: deviceViewModel,
                    onRename: { deviceToRename = $0 },
                    onRemove: { deviceToRemove = $0 },
                    onPendingAlert: { alert, _ in pendingDeviceAlert = alert },
                    zoomController: zoomController
                )
                .overlay(alignment: .bottomLeading) {
                    lastUpdatedLabel(session.store.networkMapLastUpdated)
                        .padding(DesignTokens.Spacing.md)
                }
            } else {
                ContentUnavailableView(
                    "No Network Map",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Refresh to fetch the Zigbee topology. This can take up to a minute on a busy network.")
                )
                .overlay(alignment: .bottom) {
                    Button("Refresh", action: refresh)
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
                OpenInNewWindowButton(destination: .networkMap(bridgeID: selectedBridgeID))
                if connectedSessions.count > 1 {
                    bridgePicker
                }
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
                Button(action: refresh) {
                    if selectedSession?.store.networkMapIsRefreshing == true {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(selectedSession == nil || selectedSession?.store.networkMapIsRefreshing == true)
                .accessibilityLabel("Refresh Network Map")
            }
        }
    }

    private var bridgePicker: some View {
        Menu {
            Picker("Bridge", selection: $selectedBridgeID) {
                ForEach(connectedSessions, id: \.bridgeID) { session in
                    Text(session.displayName).tag(UUID?.some(session.bridgeID))
                }
            }
        } label: {
            Label(selectedSession?.displayName ?? "Bridge", systemImage: "antenna.radiowaves.left.and.right")
        }
        .accessibilityLabel("Network Map Bridge")
    }

    private var routeBinding: Binding<DeviceRoute?> {
        selection ?? Binding(
            get: { autoOpenedDeviceRoute },
            set: { autoOpenedDeviceRoute = $0 }
        )
    }

    private func refresh() {
        guard let session = selectedSession else { return }
        session.store.networkMapIsRefreshing = true
        environment.send(
            bridge: session.bridgeID,
            topic: Z2MTopics.Request.networkMap,
            payload: .object([
                "type": .string("raw"),
                "routes": .bool(false)
            ])
        )
        if sceneNavigation.pendingNetworkMapRefreshBridgeID == session.bridgeID {
            sceneNavigation.pendingNetworkMapRefreshBridgeID = nil
        }
    }

    private func establishSelectedBridge() {
        consumePendingNavigation()
        if selectedBridgeID == nil {
            selectedBridgeID = initialBridgeID ?? sceneNavigation.selectedBridgeID
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
        selectedBridgeID = bridgeID
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
}

#Preview {
    NetworkMapView()
        .environment(AppEnvironment())
}
