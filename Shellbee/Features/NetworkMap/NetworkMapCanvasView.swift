import SwiftUI

private extension View {
    @ViewBuilder
    func networkMapCircleGlassEffect(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.12)), in: Circle())
        } else {
            self.background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(tint.opacity(0.45), lineWidth: DesignTokens.Size.hairline))
        }
    }

    @ViewBuilder
    func networkMapRoundedGlassEffect(tint: Color, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.12)), in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
                .overlay(shape.strokeBorder(tint.opacity(0.45), lineWidth: DesignTokens.Size.hairline))
        }
    }
}

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

    /// Cached separately from pan/zoom so a pinch or pan gesture —
    /// which mutates those every frame — never re-triggers this expensive
    /// hierarchical layout pass. It's recomputed only when the topology or
    /// the available canvas size actually changes (see `.task(id:)` below).
    @State private var layout: NetworkMapLayout?
    @State private var renderIndex: NetworkMapRenderIndex?
    @State private var quickLookNode: NetworkMapLayout.Node?

    private var store: AppStore { environment.scope(for: bridgeID).store }

    private struct LayoutKey: Equatable {
        let topology: NetworkTopology
        let width: CGFloat
        let minimumHeight: CGFloat
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, DesignTokens.Size.deviceGridMinimumWidth)
            let minimumHeight = max(proxy.size.height, DesignTokens.Size.networkMapMinimumHeight)
            ZStack(alignment: .topLeading) {
                if let layout, let renderIndex {
                    // This child owns the graph and node views, so changing
                    // pan/zoom on the parent repaints the transform without
                    // rebuilding every node's context menu and image task.
                    NetworkMapContentLayer(
                        bridgeID: bridgeID,
                        bridgeName: environment.registry.session(for: bridgeID)?.displayName ?? "",
                        layout: layout,
                        index: renderIndex,
                        filters: $filters,
                        onQuickLook: { node in quickLookNode = node },
                        actionsProvider: actions(for:),
                        showsMeshEdges: showsMeshEdges,
                        showsLabels: showsLabels
                    )
                } else {
                    ProgressView("Preparing Network Map")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(
                width: layout?.contentSize.width ?? proxy.size.width,
                height: layout?.contentSize.height ?? proxy.size.height
            )
            .scaleEffect(zoomController.scale, anchor: .topLeading)
            .offset(zoomController.offset)
            .contentShape(Rectangle())
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(panGesture)
            // `.scaleEffect` only changes how a view is *painted* — it never
            // shrinks the frame that view reports to its ancestors, so
            // without pinning that reported frame back down to the viewport
            // here, anything anchored to this view's edges (an overlay, a
            // sibling) would measure against the full (unscaled, possibly
            // 3000pt+) content box instead of what's actually visible.
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
            .task(id: LayoutKey(topology: topology, width: width, minimumHeight: minimumHeight)) {
                let computed = await Task.detached(priority: .userInitiated) {
                    NetworkMapLayoutEngine.layout(
                        topology: topology,
                        width: width,
                        minimumHeight: minimumHeight
                    )
                }.value
                guard !Task.isCancelled else { return }
                zoomController.updateBounds(contentSize: computed.contentSize, viewportSize: proxy.size)
                zoomController.fit()
                // Set the fitted camera before publishing the node layer. A
                // busy map therefore starts with lightweight symbols instead
                // of briefly creating every remote image task at scale 1.
                layout = computed
                renderIndex = NetworkMapRenderIndex.build(layout: computed, store: store)
            }
        }
        .onChange(of: store.networkMapRenderRevision) { _, _ in
            guard let layout else { return }
            renderIndex = NetworkMapRenderIndex.build(layout: layout, store: store)
        }
        .sheet(item: $quickLookNode) { node in
            quickLookSheet(for: node)
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
        let quality = store.devices.first(where: { $0.ieeeAddress == edge.link.sourceIEEEAddress })
            .map { store.state(for: $0.friendlyName).linkQuality ?? edge.link.linkQuality }
            ?? edge.link.linkQuality
        return .init(parentName: parent.topology.friendlyName, linkQuality: quality)
    }

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

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomController.scale = min(
                    max(zoomController.settledScale * value, DesignTokens.Size.networkMapMinimumScale),
                    DesignTokens.Size.networkMapMaximumScale
                )
            }
            .onEnded { _ in zoomController.settledScale = zoomController.scale }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                zoomController.offset = CGSize(
                    width: zoomController.settledOffset.width + value.translation.width,
                    height: zoomController.settledOffset.height + value.translation.height
                )
            }
            .onEnded { _ in zoomController.settledOffset = zoomController.offset }
    }

    private func actions(for bound: BridgeBoundDevice) -> DevicePresentationActions {
        let device = bound.device
        let state = store.state(for: device.friendlyName)
        return DevicePresentationActions(
            state: state,
            isAvailable: store.isAvailable(device.friendlyName),
            otaStatus: store.otaStatus(for: device.friendlyName),
            isIdentifying: store.identifyInProgress.contains(device.friendlyName),
            select: { selection?.wrappedValue = DeviceRoute(bridgeID: bridgeID, device: device) },
            rename: { onRename(bound) },
            remove: { onRemove(bound) },
            reconfigure: { onPendingAlert(.reconfigure(device), bridgeID) },
            interview: { onPendingAlert(.interview(device), bridgeID) },
            identify: { environment.scope(for: bridgeID).identifyDevice(device.friendlyName) },
            checkUpdate: { deviceViewModel.checkDeviceUpdate(device, environment: environment, bridgeID: bridgeID) },
            update: state.hasUpdateAvailable
                ? { deviceViewModel.updateDevice(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            schedule: state.hasUpdateAvailable
                ? { deviceViewModel.scheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
                : nil,
            unschedule: { deviceViewModel.unscheduleDeviceUpdate(device, environment: environment, bridgeID: bridgeID) }
        )
    }
}

/// Keeps the expensive render-index construction and the node view tree out
/// of the pan/zoom owner. SwiftUI can transform this whole layer at 60fps
/// without asking every node to rebuild its actions and image state.
private struct NetworkMapContentLayer: View {
    let bridgeID: UUID
    let bridgeName: String
    let layout: NetworkMapLayout
    let index: NetworkMapRenderIndex
    @Binding var filters: Set<NetworkMapFilter>
    let onQuickLook: (NetworkMapLayout.Node) -> Void
    let actionsProvider: (BridgeBoundDevice) -> DevicePresentationActions
    let showsMeshEdges: Bool
    let showsLabels: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawEdges(context: &context, layout: layout, index: index)
                for node in layout.nodes {
                    guard let symbol = context.resolveSymbol(id: node.id) else { continue }
                    let labelOffset = showsLabels
                        ? (DesignTokens.Size.networkMapNodeLabelHeight + DesignTokens.Size.networkMapNodeLabelSpacing) / 2
                        : 0
                    context.draw(
                        symbol,
                        at: CGPoint(x: node.position.x, y: node.position.y + labelOffset)
                    )
                }
            }
            symbols: {
                ForEach(layout.nodes) { node in
                    if let device = index.devicesByIEEE[node.topology.ieeeAddress] {
                        NetworkMapNodeView(
                            node: node,
                            device: device,
                            isOnline: index.onlineByNode[node.id] ?? false,
                            hasWeakLink: index.weakLinkByNode[node.id] ?? false,
                            hasUpdate: index.updateAvailableByNode[node.id] ?? false,
                            otaStatus: index.otaStatusByNode[node.id],
                            showsLabel: showsLabels,
                            isDimmed: !NetworkMapFilter.matches(
                                node: node.topology,
                                filters: filters,
                                isOffline: !(index.onlineByNode[node.id] ?? false),
                                hasWeakLink: index.weakLinkByNode[node.id] ?? false
                            )
                        )
                        .tag(node.id)
                    }
                }
            }
            NetworkMapInteractionLayer(
                bridgeID: bridgeID,
                bridgeName: bridgeName,
                layout: layout,
                index: index,
                filters: filters,
                onQuickLook: onQuickLook,
                actionsProvider: actionsProvider,
                showsLabels: showsLabels
            )
            .equatable()
        }
    }

    private func drawEdges(
        context: inout GraphicsContext,
        layout: NetworkMapLayout,
        index: NetworkMapRenderIndex
    ) {
        for edge in layout.edges {
            guard edge.isPrimary || showsMeshEdges else { continue }
            let midpointX = (edge.source.x + edge.target.x) / 2
            var path = Path()
            path.move(to: edge.source)
            path.addCurve(
                to: edge.target,
                control1: CGPoint(x: midpointX, y: edge.source.y),
                control2: CGPoint(x: midpointX, y: edge.target.y)
            )
            let online = (index.onlineByNode[edge.link.sourceIEEEAddress] ?? false)
                && (index.onlineByNode[edge.link.targetIEEEAddress] ?? false)
            let quality = index.qualityByLinkID[edge.link.id] ?? edge.link.linkQuality
            var edgeContext = context
            edgeContext.opacity = edgeMatchesFilters(edge, index: index)
                ? (edge.isPrimary
                    ? DesignTokens.Opacity.networkMapPrimaryEdge
                    : DesignTokens.Opacity.networkMapSecondaryEdge)
                : DesignTokens.Opacity.networkMapFadedEdge
            edgeContext.stroke(
                path,
                with: .color(edgeColor(linkQuality: quality, online: online)),
                style: StrokeStyle(
                    lineWidth: edge.isPrimary
                        ? DesignTokens.Size.networkMapEdgeWidth
                        : DesignTokens.Size.networkMapSecondaryEdgeWidth,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: online ? [] : [DesignTokens.Size.networkMapDashLength]
                )
            )
        }
    }

    private func edgeMatchesFilters(_ edge: NetworkMapLayout.Edge, index: NetworkMapRenderIndex) -> Bool {
        guard let source = index.nodesByID[edge.link.sourceIEEEAddress],
              let target = index.nodesByID[edge.link.targetIEEEAddress]
        else { return true }
        return NetworkMapFilter.matches(
            node: source,
            filters: filters,
            isOffline: !(index.onlineByNode[source.id] ?? false),
            hasWeakLink: index.weakLinkByNode[source.id] ?? false
        ) || NetworkMapFilter.matches(
            node: target,
            filters: filters,
            isOffline: !(index.onlineByNode[target.id] ?? false),
            hasWeakLink: index.weakLinkByNode[target.id] ?? false
        )
    }

    private func edgeColor(linkQuality: Int?, online: Bool) -> Color {
        guard online, let linkQuality else { return Color.secondary }
        if linkQuality >= 150 { return Color(red: 0.20, green: 0.48, blue: 0.76) }
        if linkQuality >= 50 { return Color(red: 0.82, green: 0.57, blue: 0.24) }
        return Color(red: 0.80, green: 0.36, blue: 0.46)
    }
}

/// All per-node/per-edge facts the map needs to draw a frame, resolved once
/// per topology/store update via O(1) dictionary lookups. Pan and zoom only
/// transform the already-built layer; they do not rebuild this index.
private struct NetworkMapRenderIndex: Equatable {
    let nodesByID: [String: NetworkTopologyNode]
    let devicesByIEEE: [String: Device]
    let onlineByNode: [String: Bool]
    let qualityByLinkID: [String: Int?]
    let weakLinkByNode: [String: Bool]
    let updateAvailableByNode: [String: Bool]
    let otaStatusByNode: [String: OTAUpdateStatus]

    static func build(layout: NetworkMapLayout, store: AppStore) -> NetworkMapRenderIndex {
        let nodesByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0.topology) })
        let devicesByIEEE = Dictionary(store.devices.map { ($0.ieeeAddress, $0) }) { first, _ in first }

        var onlineByNode: [String: Bool] = [:]
        var updateAvailableByNode: [String: Bool] = [:]
        var otaStatusByNode: [String: OTAUpdateStatus] = [:]
        onlineByNode.reserveCapacity(layout.nodes.count)
        updateAvailableByNode.reserveCapacity(layout.nodes.count)
        otaStatusByNode.reserveCapacity(layout.nodes.count)
        for node in layout.nodes {
            let topology = node.topology
            let device = devicesByIEEE[topology.ieeeAddress]
            let online = topology.role == .coordinator
                ? store.bridgeOnline
                : device.map { store.isAvailable($0.friendlyName) } ?? false
            onlineByNode[topology.id] = online
            if let device {
                updateAvailableByNode[topology.id] = store.state(for: device.friendlyName).hasUpdateAvailable
                if let status = store.otaStatus(for: device.friendlyName) {
                    otaStatusByNode[topology.id] = status
                }
            }
        }

        var qualityByLinkID: [String: Int?] = [:]
        qualityByLinkID.reserveCapacity(layout.edges.count)
        for edge in layout.edges {
            let link = edge.link
            let quality = devicesByIEEE[link.sourceIEEEAddress]
                .map { store.state(for: $0.friendlyName).linkQuality ?? link.linkQuality }
                ?? link.linkQuality
            qualityByLinkID[link.id] = quality
        }

        var weakLinkByNode: [String: Bool] = [:]
        for edge in layout.edges {
            guard (qualityByLinkID[edge.link.id].flatMap { $0 } ?? 0) < 50 else { continue }
            weakLinkByNode[edge.link.sourceIEEEAddress] = true
            weakLinkByNode[edge.link.targetIEEEAddress] = true
        }

        return NetworkMapRenderIndex(
            nodesByID: nodesByID,
            devicesByIEEE: devicesByIEEE,
            onlineByNode: onlineByNode,
            qualityByLinkID: qualityByLinkID,
            weakLinkByNode: weakLinkByNode,
            updateAvailableByNode: updateAvailableByNode,
            otaStatusByNode: otaStatusByNode
        )
    }
}

/// The tappable/draggable/context-menu layer over the map, split out into
/// its own `Equatable` view so a pan or pinch gesture — which only changes
/// `scale`/`offset` on the parent — never has to rebuild it. Each node carries
/// a context menu, drag preview, and accessibility actions, none of which
/// depend on the current zoom or pan position.
private struct NetworkMapInteractionLayer: View, Equatable {
    let bridgeID: UUID
    let bridgeName: String
    let layout: NetworkMapLayout
    let index: NetworkMapRenderIndex
    let filters: Set<NetworkMapFilter>
    let onQuickLook: (NetworkMapLayout.Node) -> Void
    let actionsProvider: (BridgeBoundDevice) -> DevicePresentationActions
    let showsLabels: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bridgeID == rhs.bridgeID && lhs.bridgeName == rhs.bridgeName
            && lhs.layout == rhs.layout && lhs.index == rhs.index
            && lhs.filters == rhs.filters && lhs.showsLabels == rhs.showsLabels
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.nodes) { node in
                if let device = index.devicesByIEEE[node.topology.ieeeAddress] {
                    let bound = BridgeBoundDevice(bridgeID: bridgeID, bridgeName: bridgeName, device: device)
                    Button {
                        onQuickLook(node)
                    } label: { Color.clear }
                    .buttonStyle(.plain)
                    .frame(
                        width: DesignTokens.Size.networkMapNodeLabelWidth,
                        height: DesignTokens.Size.networkMapInteractionTarget
                            + (showsLabels ? DesignTokens.Size.networkMapNodeLabelHeight : 0)
                    )
                    .position(
                        x: node.position.x,
                        y: node.position.y + (showsLabels
                            ? (DesignTokens.Size.networkMapNodeLabelHeight + DesignTokens.Size.networkMapNodeLabelSpacing) / 2
                            : 0)
                    )
                    .accessibilityLabel(node.topology.friendlyName)
                    .accessibilityValue(accessibilityStatus(for: node.topology))
                    .hoverEffectDisabled(true)
                    .modifier(DevicePresentationActionsModifier(
                        bound: bound,
                        actions: actionsProvider(bound),
                        pointerEffect: .none
                    ))
                }
            }
        }
    }

    private func accessibilityStatus(for node: NetworkTopologyNode) -> String {
        let status = (index.onlineByNode[node.id] ?? false) ? "Online" : "Offline"
        if index.weakLinkByNode[node.id] == true { return "\(node.role.rawValue), \(status), weak link" }
        return "\(node.role.rawValue), \(status)"
    }
}

private struct NetworkMapNodeView: View {
    let node: NetworkMapLayout.Node
    let device: Device
    let isOnline: Bool
    let hasWeakLink: Bool
    let hasUpdate: Bool
    let otaStatus: OTAUpdateStatus?
    let showsLabel: Bool
    let isDimmed: Bool

    private var size: CGFloat {
        switch node.topology.role {
        case .coordinator: DesignTokens.Size.networkMapCoordinatorNode
        case .router: DesignTokens.Size.networkMapRouterNode
        case .endDevice, .unknown: DesignTokens.Size.networkMapEndDeviceNode
        }
    }

    private var tint: Color {
        guard isOnline else { return .secondary }
        switch node.topology.role {
        case .coordinator: return .accentColor
        case .router: return .blue
        case .endDevice: return .green
        case .unknown: return .gray
        }
    }

    private var statusGradient: LinearGradient {
        if isOnline {
            return LinearGradient(
                colors: [
                    .blue.opacity(0.72),
                    .pink.opacity(0.82),
                    .orange.opacity(0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                .blue.opacity(0.82),
                .purple.opacity(0.68),
                .blue.opacity(0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: DesignTokens.Size.networkMapNodeLabelSpacing) {
            bubbleGlass
            .overlay { bubbleOutline }
            if showsLabel {
                Text(node.topology.friendlyName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Size.networkMapNodeLabelScale)
                    .frame(maxWidth: DesignTokens.Size.networkMapNodeLabelWidth)
            }
        }
        .opacity(isDimmed ? DesignTokens.Opacity.accentFill : 1)
    }
    @ViewBuilder
    private var bubbleContent: some View {
        DeviceImageView(
            device: device,
            isAvailable: isOnline,
            hasUpdate: hasUpdate,
            otaStatus: otaStatus,
            size: size * DesignTokens.Size.networkMapNodeImageRatio,
            showsAvailabilityIndicator: false
        )
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var bubbleGlass: some View {
        switch node.topology.role {
        case .endDevice:
            bubbleContent.networkMapRoundedGlassEffect(
                tint: tint,
                cornerRadius: size / 2
            )
        case .coordinator, .router, .unknown:
            bubbleContent.networkMapCircleGlassEffect(tint: tint)
        }
    }

    @ViewBuilder
    private var bubbleOutline: some View {
        if !isOnline || hasWeakLink {
            switch node.topology.role {
            case .endDevice:
                RoundedRectangle(cornerRadius: size / 2, style: .continuous)
                    .stroke(
                        statusGradient,
                        lineWidth: DesignTokens.Size.networkMapStatusGlowWidth
                    )
                    .blur(radius: DesignTokens.Size.networkMapStatusGlowRadius)
                    .opacity(DesignTokens.Opacity.networkMapStatusGlow)
            case .coordinator, .router, .unknown:
                Circle()
                    .stroke(statusGradient, lineWidth: DesignTokens.Size.networkMapStatusGlowWidth)
                    .blur(radius: DesignTokens.Size.networkMapStatusGlowRadius)
                    .opacity(DesignTokens.Opacity.networkMapStatusGlow)
            }
        }
    }
}
