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

/// Lays the mesh out the way Z2M's own frontend (and Unifi/HA topology maps)
/// do: the coordinator sits at the center and every device radiates outward
/// on a ring sized by its hop depth, so the shape of the network — who
/// routes for whom — reads at a glance and there's room to pan in every
/// direction instead of just scrolling a tall column.
enum NetworkMapLayoutEngine {
    static func layout(
        topology: NetworkTopology,
        width: CGFloat,
        minimumHeight: CGFloat
    ) -> NetworkMapLayout {
        guard !topology.nodes.isEmpty else {
            return NetworkMapLayout(nodes: [], edges: [], contentSize: CGSize(width: width, height: minimumHeight))
        }

        // Z2M's raw networkmap response can carry stale duplicate entries for
        // the same IEEE address (e.g. a device mid short-address change).
        // Keep the first occurrence so `positions` below can assume unique
        // keys instead of trapping on `Dictionary(uniqueKeysWithValues:)`.
        var seenNodeIDs: Set<String> = []
        let nodes = topology.nodes.filter { seenNodeIDs.insert($0.id).inserted }
        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        let nodeIDs = Set(nodes.map(\.id))
        let links = topology.links.filter {
            nodeIDs.contains($0.sourceIEEEAddress) && nodeIDs.contains($0.targetIEEEAddress)
        }
        let coordinator = nodes.first(where: { $0.role == .coordinator })
            ?? nodes.sorted(by: nodeOrder).first!

        let tree = spanningTree(root: coordinator.id, nodes: nodes, links: links)
        let children = childrenByParent(tree: tree, root: coordinator.id, nodesByID: nodesByID)
        let maximumDepth = max(tree.depths.values.max() ?? 0, 1)

        let countsByDepth = tree.depths.values.reduce(into: [Int: Int]()) { counts, depth in
            counts[depth, default: 0] += 1
        }
        let radiusByDepth = ringRadii(maximumDepth: maximumDepth, countsByDepth: countsByDepth)

        var angles: [String: CGFloat] = [:]
        assignAngles(node: coordinator.id, range: 0..<(2 * .pi), children: children, angles: &angles)

        let maxRadius = radiusByDepth[maximumDepth] ?? 0
        let side = max(width, minimumHeight, maxRadius * 2 + DesignTokens.Size.networkMapCoordinatorNode * 2)
        let center = CGPoint(x: side / 2, y: side / 2)

        var positioned: [NetworkMapLayout.Node] = []
        positioned.reserveCapacity(nodes.count)
        for node in nodes {
            let depth = tree.depths[node.id] ?? fallbackDepth(for: node)
            let radius = radiusByDepth[depth] ?? 0
            let angle = angles[node.id] ?? 0
            let position = radius == 0
                ? center
                : CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            positioned.append(.init(topology: node, position: position, depth: depth))
        }

        let positions = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0.position) })
        let edges = links.enumerated().compactMap { index, link -> NetworkMapLayout.Edge? in
            guard let source = positions[link.sourceIEEEAddress],
                  let target = positions[link.targetIEEEAddress]
            else { return nil }
            return .init(
                id: index,
                link: link,
                source: source,
                target: target,
                isPrimary: tree.primaryLinkIndices.contains(index)
            )
        }

        return NetworkMapLayout(
            nodes: positioned,
            edges: edges,
            contentSize: CGSize(width: side, height: side)
        )
    }

    private struct SpanningTree {
        let depths: [String: Int]
        let parents: [String: String]
        let primaryLinkIndices: Set<Int>
    }

    /// Builds a maximum-quality spanning tree from the coordinator (Prim's
    /// algorithm, greedily attaching whichever unvisited node has the best
    /// link quality to the visited set). A weak historical shortcut stays a
    /// secondary edge instead of pulling a multi-hop child onto an inner ring.
    private static func spanningTree(
        root: String,
        nodes: [NetworkTopologyNode],
        links: [NetworkTopologyLink]
    ) -> SpanningTree {
        var depths = [root: 0]
        var parents: [String: String] = [:]
        var primaryLinkIndices: Set<Int> = []
        var visited: Set<String> = [root]
        let allNodeIDs = Set(nodes.map(\.id))
        let indexedLinks = Array(links.enumerated())
        while visited.count < allNodeIDs.count {
            let candidates = indexedLinks.compactMap { index, link -> (Int, String, String, Int)? in
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
            let (index, parent, child, _) = best
            depths[child] = (depths[parent] ?? 0) + 1
            parents[child] = parent
            primaryLinkIndices.insert(index)
            visited.insert(child)
        }
        return SpanningTree(depths: depths, parents: parents, primaryLinkIndices: primaryLinkIndices)
    }

    /// Nodes the spanning tree couldn't reach (a genuinely disconnected
    /// fixture/fragment) are hung directly off the coordinator so every
    /// device still renders somewhere, ordered for deterministic layout.
    private static func childrenByParent(
        tree: SpanningTree,
        root: String,
        nodesByID: [String: NetworkTopologyNode]
    ) -> [String: [String]] {
        var children: [String: [String]] = [:]
        for (child, parent) in tree.parents {
            children[parent, default: []].append(child)
        }
        for (id, node) in nodesByID where id != root && tree.parents[id] == nil {
            children[root, default: []].append(node.id)
        }
        for key in children.keys {
            children[key]?.sort {
                guard let lhs = nodesByID[$0], let rhs = nodesByID[$1] else { return $0 < $1 }
                return nodeOrder(lhs, rhs)
            }
        }
        return children
    }

    /// Classic radial-tree angle assignment: each node gets an angular slice
    /// proportional to its subtree's leaf count, and sits at that slice's
    /// midpoint. Siblings stay grouped near their parent's angle, which is
    /// what keeps spokes from crossing each other.
    private static func assignAngles(
        node: String,
        range: Range<CGFloat>,
        children: [String: [String]],
        angles: inout [String: CGFloat]
    ) {
        angles[node] = (range.lowerBound + range.upperBound) / 2
        let kids = children[node] ?? []
        guard !kids.isEmpty else { return }
        let weights = kids.map { leafWeight(of: $0, children: children) }
        let totalWeight = CGFloat(weights.reduce(0, +))
        var cursor = range.lowerBound
        let span = range.upperBound - range.lowerBound
        for (child, weight) in zip(kids, weights) {
            let slice = span * CGFloat(weight) / totalWeight
            assignAngles(node: child, range: cursor..<(cursor + slice), children: children, angles: &angles)
            cursor += slice
        }
    }

    private static func leafWeight(of node: String, children: [String: [String]]) -> Int {
        guard let kids = children[node], !kids.isEmpty else { return 1 }
        return kids.reduce(0) { $0 + leafWeight(of: $1, children: children) }
    }

    /// Ring radius per depth: grows by a fixed base spacing, but widens
    /// further whenever a ring is too crowded for its nodes to sit
    /// `networkMapMinimumNodeSpacing` apart along the circumference.
    private static func ringRadii(maximumDepth: Int, countsByDepth: [Int: Int]) -> [Int: CGFloat] {
        var radii: [Int: CGFloat] = [0: 0]
        var previous: CGFloat = 0
        for depth in 1...maximumDepth {
            let count = countsByDepth[depth] ?? 1
            let requiredCircumference = CGFloat(count) * DesignTokens.Size.networkMapMinimumNodeSpacing
            let requiredRadius = requiredCircumference / (2 * .pi)
            let radius = max(previous + DesignTokens.Size.networkMapRingSpacing, requiredRadius)
            radii[depth] = radius
            previous = radius
        }
        return radii
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
