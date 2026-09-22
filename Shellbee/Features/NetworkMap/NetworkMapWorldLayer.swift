import SwiftUI

/// The whole map, edges and nodes, laid out once in map (world) coordinates.
///
/// Pan and zoom never touch this view: the viewport moves it with a single
/// scale + offset transform, and `Equatable` stops SwiftUI from re-running
/// this body on every gesture frame. Only a new layout, new store facts, a
/// filter change, or crossing a label/mesh zoom threshold rebuilds it.
struct NetworkMapWorldLayer: View, Equatable {
    let bridgeID: UUID
    let bridgeName: String
    let layout: NetworkMapLayout
    let index: NetworkMapRenderIndex
    let filters: Set<NetworkMapFilter>
    let showsMeshEdges: Bool
    let showsLabels: Bool
    let onQuickLook: (NetworkMapLayout.Node) -> Void
    let actionsProvider: (BridgeBoundDevice, NetworkMapRenderIndex) -> DevicePresentationActions

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bridgeID == rhs.bridgeID && lhs.bridgeName == rhs.bridgeName
            && lhs.layout == rhs.layout && lhs.index == rhs.index
            && lhs.filters == rhs.filters
            && lhs.showsMeshEdges == rhs.showsMeshEdges && lhs.showsLabels == rhs.showsLabels
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in drawEdges(in: &context) }
                .allowsHitTesting(false)

            ForEach(layout.nodes) { node in
                if let device = index.devicesByIEEE[node.topology.ieeeAddress] {
                    nodeView(node: node, device: device)
                        .position(node.position)
                }
            }
        }
        .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .topLeading)
    }

    private func nodeView(node: NetworkMapLayout.Node, device: Device) -> some View {
        let bound = BridgeBoundDevice(bridgeID: bridgeID, bridgeName: bridgeName, device: device)
        let size = NetworkMapLayoutEngine.nodeSize(for: node.topology.role)
        // A tap gesture rather than a Button: a Button still fires when a
        // pan that started on it ends with the finger over it (the bubble
        // travels with the finger), whereas a tap fails once the finger moves.
        return NetworkMapNodeView(
            node: node,
            device: device,
            isOnline: index.isOnline(node.id),
            hasWeakLink: index.hasWeakLink(node.id),
            hasUpdate: index.updateAvailableByNode[node.id] ?? false,
            otaStatus: index.otaStatusByNode[node.id],
            showsLabel: showsLabels,
            isDimmed: !index.matches(node.id, filters: filters)
        )
        .frame(width: size, height: size)
        .contentShape(.interaction, Circle().inset(by: -(DesignTokens.Size.networkMapInteractionTarget - size) / 2))
        .contentShape(.contextMenuPreview, Circle())
        .contentShape(.dragPreview, Circle())
        .onTapGesture { onQuickLook(node) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.topology.friendlyName)
        .accessibilityValue(accessibilityStatus(for: node.topology))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onQuickLook(node) }
        .modifier(DevicePresentationActionsModifier(bound: bound, actions: actionsProvider(bound, index)))
    }

    private func drawEdges(in context: inout GraphicsContext) {
        for edge in layout.edges where edge.isPrimary || showsMeshEdges {
            guard let source = index.nodesByID[edge.link.sourceIEEEAddress],
                  let target = index.nodesByID[edge.link.targetIEEEAddress]
            else { continue }
            let dx = edge.target.x - edge.source.x
            let dy = edge.target.y - edge.source.y
            let length = hypot(dx, dy)
            let sourceRadius = NetworkMapLayoutEngine.nodeSize(for: source.role) / 2
            let targetRadius = NetworkMapLayoutEngine.nodeSize(for: target.role) / 2
            guard length > sourceRadius + targetRadius else { continue }
            let unitX = dx / length
            let unitY = dy / length

            // Stop each line at the bubble rims so the glass stays clear.
            var path = Path()
            path.move(to: CGPoint(x: edge.source.x + unitX * sourceRadius, y: edge.source.y + unitY * sourceRadius))
            path.addLine(to: CGPoint(x: edge.target.x - unitX * targetRadius, y: edge.target.y - unitY * targetRadius))

            let online = index.isOnline(source.id) && index.isOnline(target.id)
            let quality = index.qualityByLinkID[edge.link.id] ?? edge.link.linkQuality
            let matches = index.matches(source.id, filters: filters) || index.matches(target.id, filters: filters)
            var edgeContext = context
            edgeContext.opacity = matches
                ? (edge.isPrimary ? DesignTokens.Opacity.networkMapPrimaryEdge : DesignTokens.Opacity.networkMapSecondaryEdge)
                : DesignTokens.Opacity.networkMapFadedEdge
            edgeContext.stroke(
                path,
                with: .color(edgeColor(linkQuality: quality, online: online)),
                style: StrokeStyle(
                    lineWidth: edge.isPrimary
                        ? DesignTokens.Size.networkMapEdgeWidth
                        : DesignTokens.Size.networkMapSecondaryEdgeWidth,
                    lineCap: .round,
                    dash: online ? [] : [DesignTokens.Size.networkMapDashLength]
                )
            )
        }
    }

    /// Healthy links stay neutral so the map reads calmly; only links worth
    /// attention (marginal or weak LQI) pick up a colour.
    private func edgeColor(linkQuality: Int?, online: Bool) -> Color {
        guard online, let linkQuality else { return .secondary }
        if linkQuality >= 100 { return .secondary }
        if linkQuality >= 50 { return .orange }
        return .red
    }

    private func accessibilityStatus(for node: NetworkTopologyNode) -> String {
        let status = index.isOnline(node.id) ? "Online" : "Offline"
        if index.hasWeakLink(node.id) { return "\(node.role.rawValue), \(status), weak link" }
        return "\(node.role.rawValue), \(status)"
    }
}
