import SwiftUI

struct NetworkMapCanvasView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let topology: NetworkTopology
    @Binding var filters: Set<NetworkMapFilter>
    let selection: Binding<DeviceRoute?>?
    @Bindable var deviceViewModel: DeviceListViewModel
    let onRename: (BridgeBoundDevice) -> Void
    let onRemove: (BridgeBoundDevice) -> Void
    let onPendingAlert: (PendingDeviceAlert, UUID) -> Void
    /// Owned by `NetworkMapView` and shared down so its toolbar's Zoom
    /// In/Out/Fit buttons can drive the same pan/zoom state this view's
    /// gestures do.
    let zoomController: NetworkMapZoomController

    /// Computed off the main actor only when the topology changes. Pan and
    /// zoom never re-run the layout (see `.task(id:)` below).
    @State private var layout: NetworkMapLayout?
    @State private var renderIndex: NetworkMapRenderIndex?
    @State private var quickLookNode: NetworkMapLayout.Node?
    @State private var viewport = Viewport(size: .zero, topInset: 0)
    @State private var indexedRevision: Int?

    private var store: AppStore { environment.scope(for: bridgeID).store }

    private struct Viewport: Equatable {
        let size: CGSize
        let topInset: CGFloat
    }

    var body: some View {
        GeometryReader { proxy in
            // The map extends up under the navigation bar so it can pass
            // beneath it; the camera keeps fitting and centring within the
            // part below the bar.
            let topInset = proxy.safeAreaInsets.top
            let fullSize = CGSize(width: proxy.size.width, height: proxy.size.height + topInset)
            NetworkMapScrollEdgeHost {
                SwiftUI.Group {
                    if let layout, let renderIndex {
                        NetworkMapViewport(
                            zoomController: zoomController,
                            viewportSize: fullSize,
                            bridgeID: bridgeID,
                            bridgeName: environment.registry.session(for: bridgeID)?.displayName ?? "",
                            layout: layout,
                            index: renderIndex,
                            filters: filters,
                            onQuickLook: { quickLookNode = $0 },
                            actionsProvider: actions(for:index:)
                        )
                    } else {
                        ProgressView("Preparing Network Map")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, topInset)
                    }
                }
                .frame(width: fullSize.width, height: fullSize.height)
            }
            .onAppear { viewport = Viewport(size: fullSize, topInset: topInset) }
            .onChange(of: Viewport(size: fullSize, topInset: topInset)) { _, next in viewport = next }
        }
        .onChange(of: viewport) { _, next in
            guard let layout else { return }
            zoomController.updateBounds(contentSize: layout.contentSize, viewportSize: next.size, topInset: next.topInset)
        }
        .task(id: topology) {
            let topology = topology
            let computed = await Task.detached(priority: .userInitiated) {
                NetworkMapLayoutEngine.layout(topology: topology, width: 0, minimumHeight: 0)
            }.value
            guard !Task.isCancelled else { return }
            zoomController.updateBounds(
                contentSize: computed.contentSize,
                viewportSize: viewport.size,
                topInset: viewport.topInset
            )
            zoomController.showInitialCamera()
            layout = computed
            renderIndex = NetworkMapRenderIndex.build(layout: computed, store: store)
            indexedRevision = store.networkMapRenderRevision
        }
        .task(id: bridgeID) { await refreshRenderIndexPeriodically() }
        .sheet(item: $quickLookNode) { node in
            quickLookSheet(for: node)
        }
    }

    /// Folds store changes into the map at most once per interval. The
    /// store's revision bumps on every device message, so reacting to each
    /// bump would rebuild the index many times a second on a busy mesh; a
    /// throttle (not a debounce, which a steady stream would starve) keeps
    /// status fresh without competing with pan and zoom for the main thread.
    private func refreshRenderIndexPeriodically() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.networkMapStatusRefresh))
            guard let layout, store.networkMapRenderRevision != indexedRevision else { continue }
            indexedRevision = store.networkMapRenderRevision
            let next = NetworkMapRenderIndex.build(layout: layout, store: store)
            if next != renderIndex { renderIndex = next }
        }
    }

    @ViewBuilder
    private func quickLookSheet(for node: NetworkMapLayout.Node) -> some View {
        if let device = store.devices.first(where: { $0.ieeeAddress == node.topology.ieeeAddress }) {
            let online = node.topology.role == .coordinator
                ? store.bridgeOnline
                : store.isAvailable(device.friendlyName)
            let connection = parentConnection(for: node)
            NetworkMapDeviceQuickLookSheet(
                device: device,
                node: node.topology,
                isOnline: online,
                hasWeakLink: (connection?.linkQuality ?? Int.max) < 50,
                connection: connection,
                onViewDetails: {
                    quickLookNode = nil
                    selection?.wrappedValue = DeviceRoute(bridgeID: bridgeID, device: device)
                }
            )
        }
    }

    /// Finds this node's parent in the primary routing tree (the neighbor
    /// one hop closer to the coordinator) purely from the resolved layout,
    /// so the quick-look sheet can show "Connected To" / LQI without the
    /// canvas exposing its internal spanning-tree bookkeeping.
    private func parentConnection(for node: NetworkMapLayout.Node) -> NetworkMapDeviceQuickLookSheet.Connection? {
        guard let layout, node.depth > 0 else { return nil }
        let nodesByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        guard let edge = layout.edges.first(where: { edge in
            guard edge.isPrimary else { return false }
            let otherID = edge.link.sourceIEEEAddress == node.id
                ? edge.link.targetIEEEAddress
                : (edge.link.targetIEEEAddress == node.id ? edge.link.sourceIEEEAddress : nil)
            guard let otherID, let other = nodesByID[otherID] else { return false }
            return other.depth == node.depth - 1
        }) else { return nil }
        let parentID = edge.link.sourceIEEEAddress == node.id ? edge.link.targetIEEEAddress : edge.link.sourceIEEEAddress
        guard let parent = nodesByID[parentID] else { return nil }
        return .init(parentName: parent.topology.friendlyName, linkQuality: edge.link.linkQuality)
    }

    /// Built from the render index, never from the live store: the world
    /// layer calls this while rendering, and reading store state there would
    /// subscribe the whole map to every device message. The store is only
    /// touched inside the closures, when a menu item is actually chosen.
    private func actions(for bound: BridgeBoundDevice, index: NetworkMapRenderIndex) -> DevicePresentationActions {
        let device = bound.device
        let nodeID = device.ieeeAddress
        let hasUpdate = index.updateAvailableByNode[nodeID] ?? false
        return DevicePresentationActions(
            state: [:],
            isAvailable: index.isOnline(nodeID),
            otaStatus: index.otaStatusByNode[nodeID],
            isIdentifying: index.identifyingDeviceNames.contains(device.friendlyName),
            select: { selection?.wrappedValue = DeviceRoute(bridgeID: bridgeID, device: device) },
            rename: { onRename(bound) },
            remove: { onRemove(bound) },
            reconfigure: { onPendingAlert(.reconfigure(device), bridgeID) },
            interview: { onPendingAlert(.interview(device), bridgeID) },
            identify: { environment.scope(for: bridgeID).identifyDevice(device.friendlyName) },
            checkUpdate: { deviceViewModel.checkDeviceUpdate(device, environment: environment, bridgeID: bridgeID) },
            update: hasUpdate
                ? { deviceViewModel.updateDevice(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            schedule: hasUpdate
                ? { deviceViewModel.scheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            unschedule: { deviceViewModel.unscheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
        )
    }
}

/// The only view that reads the camera. Each gesture frame re-runs this small
/// body, which moves the already-built `NetworkMapWorldLayer` with one
/// transform; the world layer itself is skipped through `Equatable`.
private struct NetworkMapViewport: View {
    let zoomController: NetworkMapZoomController
    let viewportSize: CGSize
    let bridgeID: UUID
    let bridgeName: String
    let layout: NetworkMapLayout
    let index: NetworkMapRenderIndex
    let filters: Set<NetworkMapFilter>
    let onQuickLook: (NetworkMapLayout.Node) -> Void
    let actionsProvider: (BridgeBoundDevice, NetworkMapRenderIndex) -> DevicePresentationActions

    /// Z2M's raw mesh includes every heard neighbor, not just the routing
    /// tree — drawing all of it at once is the "orange spaghetti" that makes
    /// the map unreadable. By default this shows only the primary routing
    /// tree (a clear overview); the full mesh reveals itself on zoom-in, or
    /// immediately when inspecting weak links/offline health.
    private var showsMeshEdges: Bool {
        zoomController.scale >= DesignTokens.Size.networkMapMeshEdgeScale
            || filters.contains(.weakLinks)
            || filters.contains(.offline)
    }

    private var showsLabels: Bool {
        zoomController.scale >= DesignTokens.Size.networkMapLabelVisibilityScale
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NetworkMapWorldLayer(
                bridgeID: bridgeID,
                bridgeName: bridgeName,
                layout: layout,
                index: index,
                filters: filters,
                showsMeshEdges: showsMeshEdges,
                showsLabels: showsLabels,
                onQuickLook: onQuickLook,
                actionsProvider: actionsProvider
            )
            .equatable()
            .scaleEffect(zoomController.scale, anchor: .topLeading)
            .offset(zoomController.offset)
        }
        .frame(width: viewportSize.width, height: viewportSize.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(panGesture)
        .simultaneousGesture(magnifyGesture)
        .clipped()
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { zoomController.pan(translation: $0.translation) }
            .onEnded {
                zoomController.endPan(
                    translation: $0.translation,
                    predictedEndTranslation: $0.predictedEndTranslation
                )
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { zoomController.magnify(by: $0.magnification, anchor: $0.startLocation) }
            .onEnded { _ in zoomController.endMagnify() }
    }
}

/// Hosts the map inside a scroll view that never scrolls. iOS only draws the
/// soft scroll-edge effect under the navigation bar for scroll-view content,
/// so without this the map would stop hard at the bar instead of blurring
/// softly beneath it like every other screen. Pan and zoom stay with the
/// map's own gestures.
private struct NetworkMapScrollEdgeHost<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        // The content is exactly one bar taller than the visible area and
        // rests scrolled to the bottom, so its top genuinely sits under the
        // bar (the edge effect ignores content only drawn there by offset).
        ScrollView {
            content
        }
        .defaultScrollAnchor(.bottom)
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
    }
}
