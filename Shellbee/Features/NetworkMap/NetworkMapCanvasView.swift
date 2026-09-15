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

    /// Cached separately from pan/zoom so a pinch or pan gesture —
    /// which mutates those every frame — never re-triggers this expensive
    /// hierarchical layout pass. It's recomputed only when the topology or
    /// the available canvas size actually changes (see `.task(id:)` below).
    @State private var layout: NetworkMapLayout?
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
            let resolvedLayout = layout ?? NetworkMapLayoutEngine.layout(
                topology: topology,
                width: width,
                minimumHeight: minimumHeight
            )
            let index = NetworkMapRenderIndex.build(layout: resolvedLayout, store: store)
            ZStack(alignment: .topLeading) {
                graph(layout: resolvedLayout, index: index)
                // `.equatable()` is the whole point here: without it, every
                // pinch/pan frame (a `scale`/`offset` @State change on this
                // view) would re-run this closure and reconstruct ~150
                // Buttons each carrying a `.contextMenu`, `.draggable`, and
                // 7 accessibility actions — none of which depend on
                // scale/offset at all. Equatable lets SwiftUI recognize
                // "same layout, same index" and skip rebuilding the whole
                // interactive layer on every gesture tick, which is what
                // was making the map lag while panning/zooming.
                NetworkMapInteractionLayer(
                    bridgeID: bridgeID,
                    bridgeName: environment.registry.session(for: bridgeID)?.displayName ?? "",
                    layout: resolvedLayout,
                    index: index,
                    onQuickLook: { node in quickLookNode = node },
                    actionsProvider: actions(for:)
                )
                .equatable()
            }
            .frame(width: resolvedLayout.contentSize.width, height: resolvedLayout.contentSize.height)
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
                let wasEmpty = layout == nil
                let computed = NetworkMapLayoutEngine.layout(
                    topology: topology,
                    width: width,
                    minimumHeight: minimumHeight
                )
                layout = computed
                zoomController.updateBounds(contentSize: computed.contentSize, viewportSize: proxy.size)
                if wasEmpty { zoomController.fit() }
            }
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

    private func graph(layout: NetworkMapLayout, index: NetworkMapRenderIndex) -> some View {
        TimelineView(.animation(
            minimumInterval: DesignTokens.Duration.frameInterval,
            paused: !index.hasActiveNodes
        )) { timeline in
            Canvas { context, _ in
                drawEdges(context: &context, layout: layout, index: index)
                drawNodes(context: &context, layout: layout, index: index, date: timeline.date)
            } symbols: {
                ForEach(layout.nodes) { node in
                    if let device = index.devicesByIEEE[node.topology.ieeeAddress] {
                        DeviceImageView(
                            device: device,
                            isAvailable: index.onlineByNode[node.id] ?? false,
                            hasUpdate: store.state(for: device.friendlyName).hasUpdateAvailable,
                            otaStatus: store.otaStatus(for: device.friendlyName),
                            size: nodeSize(node.topology)
                        )
                        .tag(node.id)
                    }
                }
            }
        }
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

    private func drawEdges(context: inout GraphicsContext, layout: NetworkMapLayout, index: NetworkMapRenderIndex) {
        let showMesh = showsMeshEdges
        for edge in layout.edges {
            guard edge.isPrimary || showMesh else { continue }
            var path = Path()
            path.move(to: edge.source)
            path.addLine(to: edge.target)
            let online = (index.onlineByNode[edge.link.sourceIEEEAddress] ?? false)
                && (index.onlineByNode[edge.link.targetIEEEAddress] ?? false)
            let quality = index.qualityByLinkID[edge.link.id] ?? edge.link.linkQuality
            let faded = !edgeMatchesFilters(edge, index: index)
            var edgeContext = context
            edgeContext.opacity = faded
                ? DesignTokens.Opacity.accentFill
                : (edge.isPrimary ? 1 : DesignTokens.Opacity.overlay)
            edgeContext.stroke(
                path,
                with: .color(edgeColor(linkQuality: quality, online: online)),
                style: StrokeStyle(
                    lineWidth: edge.isPrimary
                        ? DesignTokens.Size.networkMapEdgeWidth
                        : DesignTokens.Size.networkMapSecondaryEdgeWidth,
                    dash: online ? [] : [DesignTokens.Size.networkMapDashLength]
                )
            )
        }
    }

    private func drawNodes(
        context: inout GraphicsContext,
        layout: NetworkMapLayout,
        index: NetworkMapRenderIndex,
        date: Date
    ) {
        for node in layout.nodes {
            let size = nodeSize(node.topology)
            let frame = CGRect(
                x: node.position.x - size / 2,
                y: node.position.y - size / 2,
                width: size,
                height: size
            )
            let online = index.onlineByNode[node.id] ?? false
            let weak = index.weakLinkByNode[node.id] ?? false
            let matches = NetworkMapFilter.matches(
                node: node.topology,
                filters: filters,
                isOffline: !online,
                hasWeakLink: weak
            )
            var nodeContext = context
            nodeContext.opacity = matches ? 1 : DesignTokens.Opacity.accentFill
            let path = nodePath(role: node.topology.role, frame: frame)
            drawGlassBackground(in: &nodeContext, path: path, frame: frame, tint: nodeColor(node.topology, online: online), online: online)
            if !online {
                nodeContext.stroke(
                    path,
                    with: .color(.secondary),
                    style: StrokeStyle(
                        lineWidth: DesignTokens.Size.networkMapSecondaryEdgeWidth,
                        dash: [DesignTokens.Size.networkMapDashLength]
                    )
                )
            }
            if weak {
                nodeContext.stroke(
                    path,
                    with: .color(.red),
                    lineWidth: DesignTokens.Size.networkMapWeakRingWidth
                )
            }
            if index.activeByNode[node.id] == true {
                let pulse = CGFloat((sin(date.timeIntervalSinceReferenceDate * 4) + 1) / 2)
                nodeContext.stroke(
                    Path(ellipseIn: frame.insetBy(
                        dx: -(DesignTokens.Spacing.xs + pulse * DesignTokens.Spacing.xs),
                        dy: -(DesignTokens.Spacing.xs + pulse * DesignTokens.Spacing.xs)
                    )),
                    with: .color(.blue.opacity(DesignTokens.Opacity.secondaryText)),
                    lineWidth: DesignTokens.Size.networkMapEdgeWidth
                )
            }

            if let symbol = nodeContext.resolveSymbol(id: node.id) {
                nodeContext.draw(symbol, at: node.position, anchor: .center)
            } else {
                let icon = nodeContext.resolve(Image(systemName: symbolName(for: node.topology)))
                nodeContext.draw(icon, at: node.position, anchor: .center)
            }
            let label = nodeContext.resolve(
                Text(node.topology.friendlyName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
            )
            nodeContext.draw(
                label,
                at: CGPoint(
                    x: node.position.x,
                    y: node.position.y + size / 2 + DesignTokens.Spacing.md
                ),
                anchor: .center
            )
        }
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

    private func nodeSize(_ node: NetworkTopologyNode) -> CGFloat {
        switch node.role {
        case .coordinator: DesignTokens.Size.networkMapCoordinatorNode
        case .router: DesignTokens.Size.networkMapRouterNode
        case .endDevice, .unknown: DesignTokens.Size.networkMapEndDeviceNode
        }
    }

    private func nodePath(role: NetworkTopologyNode.Role, frame: CGRect) -> Path {
        switch role {
        case .endDevice:
            Path(roundedRect: frame, cornerRadius: frame.width / 2, style: .continuous)
        case .coordinator, .router, .unknown:
            Path(ellipseIn: frame)
        }
    }

    /// Approximates iOS's Liquid Glass look — a tinted, translucent capsule
    /// with a glossy highlight — for the node background. `Canvas` draws
    /// immediately into a bitmap with no access to a live backdrop to blur,
    /// so this can't be the real `.glassEffect()` material (that needs an
    /// actual layered SwiftUI view behind it); it's a gradient-based stand-in
    /// that reads the same way — tinted glass, not a flat colored disc.
    private func drawGlassBackground(in context: inout GraphicsContext, path: Path, frame: CGRect, tint: Color, online: Bool) {
        context.fill(path, with: .color(tint.opacity(online ? 0.32 : 0.16)))
        context.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [.white.opacity(online ? 0.6 : 0.25), .white.opacity(0)]),
                center: CGPoint(x: frame.minX + frame.width * 0.32, y: frame.minY + frame.height * 0.28),
                startRadius: 0,
                endRadius: frame.width * 0.75
            )
        )
        context.stroke(path, with: .color(tint.opacity(online ? 0.55 : 0.3)), lineWidth: 1)
    }

    private func nodeColor(_ node: NetworkTopologyNode, online: Bool) -> Color {
        guard online else { return Color.secondary.opacity(DesignTokens.Opacity.softFill) }
        switch node.role {
        case .coordinator: return .accentColor
        case .router: return .blue
        case .endDevice: return .green
        case .unknown: return .gray
        }
    }

    private func symbolName(for node: NetworkTopologyNode) -> String {
        switch node.role {
        case .coordinator: "network"
        case .router: "router"
        case .endDevice: "leaf.fill"
        case .unknown: "questionmark"
        }
    }

    private func edgeColor(linkQuality: Int?, online: Bool) -> Color {
        guard online, let linkQuality else { return .gray }
        if linkQuality >= 150 { return .green }
        if linkQuality >= 50 { return .orange }
        return .red
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

/// All per-node/per-edge facts the canvas needs to draw a frame, resolved
/// once per topology/store update via O(1) dictionary lookups instead of
/// the linear (or worse) scans this replaced. Building this used to happen
/// implicitly inside the 60fps `TimelineView` draw closure — for a mesh with
/// hundreds of links that turned every animated frame into an O(nodes ×
/// links) pass, which is what made the map lag once anything (an interview,
/// an OTA) kept the pulse animation running.
private struct NetworkMapRenderIndex: Equatable {
    let nodesByID: [String: NetworkTopologyNode]
    let devicesByIEEE: [String: Device]
    let onlineByNode: [String: Bool]
    let qualityByLinkID: [String: Int?]
    let weakLinkByNode: [String: Bool]
    let activeByNode: [String: Bool]

    var hasActiveNodes: Bool { activeByNode.values.contains(true) }

    static func build(layout: NetworkMapLayout, store: AppStore) -> NetworkMapRenderIndex {
        let nodesByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0.topology) })
        let devicesByIEEE = Dictionary(store.devices.map { ($0.ieeeAddress, $0) }) { first, _ in first }

        var onlineByNode: [String: Bool] = [:]
        var activeByNode: [String: Bool] = [:]
        onlineByNode.reserveCapacity(layout.nodes.count)
        activeByNode.reserveCapacity(layout.nodes.count)
        for node in layout.nodes {
            let topology = node.topology
            let device = devicesByIEEE[topology.ieeeAddress]
            let online = topology.role == .coordinator
                ? store.bridgeOnline
                : device.map { store.isAvailable($0.friendlyName) } ?? false
            onlineByNode[topology.id] = online
            activeByNode[topology.id] = device.map { device in
                device.isInterviewing || store.otaStatus(for: device.friendlyName)?.isActive == true
            } ?? false
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
            activeByNode: activeByNode
        )
    }
}

/// The tappable/draggable/context-menu layer over the map, split out into
/// its own `Equatable` view so a pan or pinch gesture — which only changes
/// `scale`/`offset` on the parent — never has to rebuild it. See the
/// `.equatable()` call site in `NetworkMapCanvasView.body` for why that
/// matters: each of these rows carries a `.contextMenu`, a `.draggable`, and
/// several accessibility actions, and none of that depends on the current
/// zoom or pan position.
private struct NetworkMapInteractionLayer: View, Equatable {
    let bridgeID: UUID
    let bridgeName: String
    let layout: NetworkMapLayout
    let index: NetworkMapRenderIndex
    let onQuickLook: (NetworkMapLayout.Node) -> Void
    let actionsProvider: (BridgeBoundDevice) -> DevicePresentationActions

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bridgeID == rhs.bridgeID && lhs.bridgeName == rhs.bridgeName
            && lhs.layout == rhs.layout && lhs.index == rhs.index
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.nodes) { node in
                if let device = index.devicesByIEEE[node.topology.ieeeAddress] {
                    let bound = BridgeBoundDevice(bridgeID: bridgeID, bridgeName: bridgeName, device: device)
                    Button {
                        onQuickLook(node)
                    } label: {
                        Color.clear
                            .frame(
                                width: DesignTokens.Size.networkMapInteractionTarget,
                                height: DesignTokens.Size.networkMapInteractionTarget
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(node.position)
                    .accessibilityLabel(node.topology.friendlyName)
                    .accessibilityValue(accessibilityStatus(for: node.topology))
                    .modifier(DevicePresentationActionsModifier(
                        bound: bound,
                        actions: actionsProvider(bound)
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
