import CoreGraphics
import Foundation

struct NetworkMapLayout: Equatable {
    struct Node: Identifiable, Equatable {
        let topology: NetworkTopologyNode
        let position: CGPoint
        let depth: Int

        var id: String { topology.id }
    }

    struct Edge: Identifiable, Equatable {
        let id: Int
        let link: NetworkTopologyLink
        let source: CGPoint
        let target: CGPoint
        let isPrimary: Bool
    }

    let nodes: [Node]
    let edges: [Edge]
    let contentSize: CGSize
}

enum NetworkMapLayoutEngine {
    static func layout(
        topology: NetworkTopology,
        width: CGFloat,
        minimumHeight: CGFloat
    ) -> NetworkMapLayout {
        guard !topology.nodes.isEmpty else {
            return NetworkMapLayout(nodes: [], edges: [], contentSize: CGSize(width: width, height: minimumHeight))
        }

        let nodeIDs = Set(topology.nodes.map(\.id))
        let links = topology.links.filter {
            nodeIDs.contains($0.sourceIEEEAddress) && nodeIDs.contains($0.targetIEEEAddress)
        }
        let coordinator = topology.nodes.first(where: { $0.role == .coordinator })
            ?? topology.nodes.sorted(by: nodeOrder).first!
        let depths = hierarchicalDepths(root: coordinator.id, nodes: topology.nodes, links: links)
        let grouped = Dictionary(grouping: topology.nodes) { node in
            depths[node.id] ?? fallbackDepth(for: node)
        }
        let maximumDepth = max(grouped.keys.max() ?? 0, 1)
        let contentHeight = max(
            minimumHeight,
            DesignTokens.Spacing.xxl * 2
                + CGFloat(maximumDepth) * DesignTokens.Size.networkMapLayerHeight
        )

        var positioned: [NetworkMapLayout.Node] = []
        for depth in grouped.keys.sorted() {
            let level = (grouped[depth] ?? []).sorted(by: nodeOrder)
            for (index, node) in level.enumerated() {
                let x = width * CGFloat(index + 1) / CGFloat(level.count + 1)
                let y = DesignTokens.Spacing.xxl
                    + CGFloat(depth) * DesignTokens.Size.networkMapLayerHeight
                positioned.append(.init(topology: node, position: CGPoint(x: x, y: y), depth: depth))
            }
        }

        let positions = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0.position) })
        let primaryLinks = primaryLinkIndices(links: links, depths: depths, root: coordinator.id)
        let edges = links.enumerated().compactMap { index, link -> NetworkMapLayout.Edge? in
            guard let source = positions[link.sourceIEEEAddress],
                  let target = positions[link.targetIEEEAddress]
            else { return nil }
            return .init(
                id: index,
                link: link,
                source: source,
                target: target,
                isPrimary: primaryLinks.contains(index)
            )
        }

        return NetworkMapLayout(
            nodes: positioned,
            edges: edges,
            contentSize: CGSize(width: width, height: contentHeight)
        )
    }

    /// Builds a maximum-quality spanning tree from the coordinator. A weak
    /// historical shortcut therefore stays a secondary edge instead of
    /// pulling a multi-hop child into the coordinator row.
    private static func hierarchicalDepths(
        root: String,
        nodes: [NetworkTopologyNode],
        links: [NetworkTopologyLink]
    ) -> [String: Int] {
        var result = [root: 0]
        var visited: Set<String> = [root]
        let allNodeIDs = Set(nodes.map(\.id))
        while visited.count < allNodeIDs.count {
            let candidates = links.enumerated().compactMap { index, link -> (Int, String, String, Int)? in
                let sourceVisited = visited.contains(link.sourceIEEEAddress)
                let targetVisited = visited.contains(link.targetIEEEAddress)
                guard sourceVisited != targetVisited else { return nil }
                let parent = sourceVisited ? link.sourceIEEEAddress : link.targetIEEEAddress
                let child = sourceVisited ? link.targetIEEEAddress : link.sourceIEEEAddress
                return (index, parent, child, link.linkQuality ?? -1)
            }
            guard let best = candidates.sorted(by: {
                if $0.3 != $1.3 { return $0.3 > $1.3 }
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return $0.2 < $1.2
            }).first else { break }
            result[best.2] = (result[best.1] ?? 0) + 1
            visited.insert(best.2)
        }
        return result
    }

    private static func primaryLinkIndices(
        links: [NetworkTopologyLink],
        depths: [String: Int],
        root: String
    ) -> Set<Int> {
        var result: Set<Int> = []
        let nodeIDs = Set(links.flatMap { [$0.sourceIEEEAddress, $0.targetIEEEAddress] })
        for nodeID in nodeIDs where nodeID != root {
            guard let nodeDepth = depths[nodeID] else { continue }
            let candidates = links.enumerated().filter { _, link in
                guard link.sourceIEEEAddress == nodeID || link.targetIEEEAddress == nodeID else { return false }
                let other = link.sourceIEEEAddress == nodeID
                    ? link.targetIEEEAddress
                    : link.sourceIEEEAddress
                return depths[other] == nodeDepth - 1
            }
            if let best = candidates.max(by: {
                ($0.element.linkQuality ?? -1) < ($1.element.linkQuality ?? -1)
            }) {
                result.insert(best.offset)
            }
        }
        return result
    }

    private static func fallbackDepth(for node: NetworkTopologyNode) -> Int {
        switch node.role {
        case .coordinator: 0
        case .router: 1
        case .endDevice, .unknown: 2
        }
    }

    private static func nodeOrder(_ lhs: NetworkTopologyNode, _ rhs: NetworkTopologyNode) -> Bool {
        if lhs.role != rhs.role {
            return roleOrder(lhs.role) < roleOrder(rhs.role)
        }
        let nameOrder = lhs.friendlyName.localizedCaseInsensitiveCompare(rhs.friendlyName)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.ieeeAddress < rhs.ieeeAddress
    }

    private static func roleOrder(_ role: NetworkTopologyNode.Role) -> Int {
        switch role {
        case .coordinator: 0
        case .router: 1
        case .endDevice: 2
        case .unknown: 3
        }
    }
}
