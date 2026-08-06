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

    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    private var store: AppStore { environment.scope(for: bridgeID).store }

    var body: some View {
        GeometryReader { proxy in
            let layout = NetworkMapLayoutEngine.layout(
                topology: topology,
                width: max(proxy.size.width, DesignTokens.Size.deviceGridMinimumWidth),
                minimumHeight: max(proxy.size.height, DesignTokens.Size.networkMapMinimumHeight)
            )
            ZStack(alignment: .topLeading) {
                graph(layout: layout)
                interactionLayer(layout: layout)
            }
            .frame(width: layout.contentSize.width, height: layout.contentSize.height)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(offset)
            .contentShape(Rectangle())
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(panGesture)
            .overlay(alignment: .topTrailing) {
                Button {
                    snapToFit(layout: layout, viewport: proxy.size)
                } label: {
                    Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .padding(DesignTokens.Spacing.md)
                .accessibilityLabel("Fit Network Map")
            }
            .onAppear { snapToFit(layout: layout, viewport: proxy.size) }
        }
        .clipped()
    }

    private func graph(layout: NetworkMapLayout) -> some View {
        TimelineView(.animation(
            minimumInterval: DesignTokens.Duration.frameInterval,
            paused: !hasActiveNodes
        )) { timeline in
            Canvas { context, _ in
                drawEdges(context: &context, layout: layout)
                drawNodes(context: &context, layout: layout, date: timeline.date)
            } symbols: {
                ForEach(layout.nodes) { node in
                    if let device = device(for: node.topology) {
                        DeviceImageView(
                            device: device,
                            isAvailable: isOnline(node.topology),
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

    private func interactionLayer(layout: NetworkMapLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.nodes) { node in
                if let device = device(for: node.topology) {
                    let bound = BridgeBoundDevice(
                        bridgeID: bridgeID,
                        bridgeName: environment.registry.session(for: bridgeID)?.displayName ?? "",
                        device: device
                    )
                    Button {
                        selection?.wrappedValue = DeviceRoute(bridgeID: bridgeID, device: device)
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
                        actions: actions(for: bound)
                    ))
                }
            }
        }
    }

    private func drawEdges(context: inout GraphicsContext, layout: NetworkMapLayout) {
        for edge in layout.edges {
            var path = Path()
            path.move(to: edge.source)
            let middleY = (edge.source.y + edge.target.y) / 2
            path.addCurve(
                to: edge.target,
                control1: CGPoint(x: edge.source.x, y: middleY),
                control2: CGPoint(x: edge.target.x, y: middleY)
            )
            let online = isOnline(nodeID: edge.link.sourceIEEEAddress)
                && isOnline(nodeID: edge.link.targetIEEEAddress)
            let quality = effectiveLinkQuality(edge.link)
            let faded = !edgeMatchesFilters(edge, layout: layout)
            var edgeContext = context
            edgeContext.opacity = faded ? DesignTokens.Opacity.accentFill : 1
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
            let online = isOnline(node.topology)
            let weak = hasWeakLink(node.topology.ieeeAddress)
            let matches = NetworkMapFilter.matches(
                node: node.topology,
                filters: filters,
                isOffline: !online,
                hasWeakLink: weak
            )
            var nodeContext = context
            nodeContext.opacity = matches ? 1 : DesignTokens.Opacity.accentFill
            let path = nodePath(role: node.topology.role, frame: frame)
            nodeContext.fill(path, with: .color(nodeColor(node.topology, online: online)))
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
            if isActive(node.topology) {
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

            if scale >= DesignTokens.Size.networkMapThumbnailScale,
               let symbol = nodeContext.resolveSymbol(id: node.id) {
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
                scale = min(
                    max(settledScale * value, DesignTokens.Size.networkMapMinimumScale),
                    DesignTokens.Size.networkMapMaximumScale
                )
            }
            .onEnded { _ in settledScale = scale }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
            }
            .onEnded { _ in settledOffset = offset }
    }

    private func snapToFit(layout: NetworkMapLayout, viewport: CGSize) {
        let nextScale = min(
            viewport.width / layout.contentSize.width,
            viewport.height / layout.contentSize.height,
            1
        )
        scale = max(nextScale, DesignTokens.Size.networkMapMinimumScale)
        settledScale = scale
        offset = .zero
        settledOffset = .zero
    }

    private func device(for node: NetworkTopologyNode) -> Device? {
        store.devices.first { $0.ieeeAddress == node.ieeeAddress }
    }

    private func node(for id: String, layout: NetworkMapLayout) -> NetworkTopologyNode? {
        layout.nodes.first { $0.id == id }?.topology
    }

    private func isOnline(_ node: NetworkTopologyNode) -> Bool {
        if node.role == .coordinator { return store.bridgeOnline }
        guard let device = device(for: node) else { return false }
        return store.isAvailable(device.friendlyName)
    }

    private func isOnline(nodeID: String) -> Bool {
        guard let node = topology.nodes.first(where: { $0.id == nodeID }) else { return false }
        return isOnline(node)
    }

    private func effectiveLinkQuality(_ link: NetworkTopologyLink) -> Int? {
        guard let node = topology.nodes.first(where: { $0.id == link.sourceIEEEAddress }),
              let device = device(for: node)
        else { return link.linkQuality }
        return store.state(for: device.friendlyName).linkQuality ?? link.linkQuality
    }

    private func hasWeakLink(_ nodeID: String) -> Bool {
        topology.links.contains { link in
            (link.sourceIEEEAddress == nodeID || link.targetIEEEAddress == nodeID)
                && (effectiveLinkQuality(link) ?? 0) < 50
        }
    }

    private func edgeMatchesFilters(_ edge: NetworkMapLayout.Edge, layout: NetworkMapLayout) -> Bool {
        guard let source = node(for: edge.link.sourceIEEEAddress, layout: layout),
              let target = node(for: edge.link.targetIEEEAddress, layout: layout)
        else { return true }
        return NetworkMapFilter.matches(
            node: source,
            filters: filters,
            isOffline: !isOnline(source),
            hasWeakLink: hasWeakLink(source.id)
        ) || NetworkMapFilter.matches(
            node: target,
            filters: filters,
            isOffline: !isOnline(target),
            hasWeakLink: hasWeakLink(target.id)
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

    private var hasActiveNodes: Bool {
        topology.nodes.contains(where: isActive)
    }

    private func isActive(_ node: NetworkTopologyNode) -> Bool {
        guard let device = device(for: node) else { return false }
        return device.isInterviewing || store.otaStatus(for: device.friendlyName)?.isActive == true
    }

    private func accessibilityStatus(for node: NetworkTopologyNode) -> String {
        let status = isOnline(node) ? "Online" : "Offline"
        if hasWeakLink(node.id) { return "\(node.role.rawValue), \(status), weak link" }
        return "\(node.role.rawValue), \(status)"
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
