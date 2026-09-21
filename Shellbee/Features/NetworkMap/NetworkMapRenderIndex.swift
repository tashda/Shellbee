import SwiftUI

/// All per-node/per-edge facts the map needs to draw a frame, resolved once
/// per topology/store update via O(1) dictionary lookups. Pan and zoom only
/// transform the already-built layer; they do not rebuild this index.
struct NetworkMapRenderIndex: Equatable {
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

    func isOnline(_ nodeID: String) -> Bool { onlineByNode[nodeID] ?? false }

    func hasWeakLink(_ nodeID: String) -> Bool { weakLinkByNode[nodeID] ?? false }

    func matches(_ nodeID: String, filters: Set<NetworkMapFilter>) -> Bool {
        guard let node = nodesByID[nodeID] else { return true }
        return NetworkMapFilter.matches(
            node: node,
            filters: filters,
            isOffline: !isOnline(nodeID),
            hasWeakLink: hasWeakLink(nodeID)
        )
    }
}
