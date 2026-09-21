import SwiftUI

/// All per-node/per-edge facts the map needs to draw a frame, resolved once
/// per topology/store update via O(1) dictionary lookups. Pan and zoom only
/// transform the already-built layer; they do not rebuild this index, and it
/// only changes when something the map shows (availability, updates, OTA,
/// the device list) changes.
struct NetworkMapRenderIndex: Equatable {
    let nodesByID: [String: NetworkTopologyNode]
    let devicesByIEEE: [String: Device]
    let onlineByNode: [String: Bool]
    let qualityByLinkID: [String: Int?]
    let weakLinkByNode: [String: Bool]
    let updateAvailableByNode: [String: Bool]
    let otaStatusByNode: [String: OTAUpdateStatus]
    let identifyingDeviceNames: Set<String>

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

        // Link quality comes from the network scan, not from each device's
        // live `linkquality`. The live value changes with every state message
        // (several per second on a real mesh) and only describes the last
        // hop a message took, so reading it would repaint the whole map
        // continuously while describing the links less accurately.
        let qualityByLinkID = Dictionary(
            layout.edges.map { ($0.link.id, $0.link.linkQuality) }
        ) { first, _ in first }

        // A weak link belongs to the device hanging off it: the child end of
        // its route to the coordinator. Flagging both ends would mark every
        // busy router (and the coordinator) weak because of one bad child.
        let depthByID = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0.depth) })
        var weakLinkByNode: [String: Bool] = [:]
        for edge in layout.edges where edge.isPrimary {
            guard let quality = edge.link.linkQuality, quality < 50 else { continue }
            let source = edge.link.sourceIEEEAddress
            let target = edge.link.targetIEEEAddress
            let child = (depthByID[source] ?? 0) >= (depthByID[target] ?? 0) ? source : target
            weakLinkByNode[child] = true
        }

        return NetworkMapRenderIndex(
            nodesByID: nodesByID,
            devicesByIEEE: devicesByIEEE,
            onlineByNode: onlineByNode,
            qualityByLinkID: qualityByLinkID,
            weakLinkByNode: weakLinkByNode,
            updateAvailableByNode: updateAvailableByNode,
            otaStatusByNode: otaStatusByNode,
            identifyingDeviceNames: store.identifyInProgress
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
