import CoreGraphics
import Foundation

struct NetworkMapLayout: Equatable, Sendable {
    struct Node: Identifiable, Equatable, Sendable {
        let topology: NetworkTopologyNode
        let position: CGPoint
        let depth: Int

        nonisolated var id: String { topology.id }
    }

    struct Edge: Identifiable, Equatable, Sendable {
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

/// Lays the mesh as a compact, deterministic routing graph. The routing tree
/// comes from Z2M's explicit parent/child relationships whenever available;
/// only then do we fall back to radio quality. A bounded force pass keeps
/// related devices together without turning a busy network into a wheel, and
/// a final footprint pass guarantees no two bubbles or labels overlap.
nonisolated enum NetworkMapLayoutEngine {
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

        let nodeIDs = Set(nodes.map(\.id))
        let links = topology.links.filter {
            nodeIDs.contains($0.sourceIEEEAddress) && nodeIDs.contains($0.targetIEEEAddress)
        }
        let coordinator = nodes.first(where: { $0.role == .coordinator })
            ?? nodes.sorted(by: nodeOrder).first!

        let tree = spanningTree(root: coordinator.id, nodes: nodes, links: links)
        let positioning = forceDirectedPositions(
            nodes: nodes,
            tree: tree,
            width: width,
            minimumHeight: minimumHeight
        )

        let positioned = nodes.map { node in
            let depth = tree.depths[node.id] ?? fallbackDepth(for: node)
            return NetworkMapLayout.Node(
                topology: node,
                position: positioning.positions[node.id] ?? .zero,
                depth: depth
            )
        }

        let positionsByID = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0.position) })
        let edges = links.enumerated().compactMap { index, link -> NetworkMapLayout.Edge? in
            guard let source = positionsByID[link.sourceIEEEAddress],
                  let target = positionsByID[link.targetIEEEAddress]
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
            contentSize: positioning.contentSize
        )
    }

    private struct SpanningTree {
        let depths: [String: Int]
        let primaryLinkIndices: Set<Int>
        let parentByID: [String: String]
    }

    /// Builds a maximum-quality spanning tree from the coordinator (Prim's
    /// algorithm, greedily attaching whichever unvisited node has the best
    /// link quality to the visited set). The heap keeps this O(E log E), which
    /// matters when a raw map contains hundreds of heard-neighbor links.
    private static func spanningTree(
        root: String,
        nodes: [NetworkTopologyNode],
        links: [NetworkTopologyLink]
    ) -> SpanningTree {
        var depths = [root: 0]
        var primaryLinkIndices: Set<Int> = []
        var parentByID: [String: String] = [:]
        var visited: Set<String> = [root]
        let allNodeIDs = Set(nodes.map(\.id))
        var adjacency: [String: [(index: Int, neighbor: String, quality: Int, relationshipPriority: Int)]] = [:]
        adjacency.reserveCapacity(nodes.count)
        for (index, link) in links.enumerated() {
            let quality = link.linkQuality ?? -1
            // Z2M reports `Neighbor is a child` from the child's perspective
            // and `Neighbor is a parent` from the parent's perspective. Both
            // forms encode the same directed parent -> child route.
            switch link.relationship {
            case 0: // Neighbor is parent: source is the parent of target.
                adjacency[link.sourceIEEEAddress, default: []].append(
                    (index, link.targetIEEEAddress, quality, 2)
                )
                adjacency[link.targetIEEEAddress, default: []].append(
                    (index, link.sourceIEEEAddress, quality, 0)
                )
            case 1: // Neighbor is child: target is the parent of source.
                adjacency[link.targetIEEEAddress, default: []].append(
                    (index, link.sourceIEEEAddress, quality, 2)
                )
                adjacency[link.sourceIEEEAddress, default: []].append(
                    (index, link.targetIEEEAddress, quality, 0)
                )
            default:
                // Some adapters omit relationship metadata. Keep those links
                // as a quality-based fallback rather than dropping devices.
                adjacency[link.sourceIEEEAddress, default: []].append(
                    (index, link.targetIEEEAddress, quality, 0)
                )
                adjacency[link.targetIEEEAddress, default: []].append(
                    (index, link.sourceIEEEAddress, quality, 0)
                )
            }
        }

        var candidates = MaxHeap<SpanningTreeCandidate>()
        func enqueue(_ parent: String) {
            for edge in adjacency[parent] ?? [] where !visited.contains(edge.neighbor) {
                candidates.insert(.init(
                    index: edge.index,
                    parent: parent,
                    child: edge.neighbor,
                    quality: edge.quality,
                    relationshipPriority: edge.relationshipPriority
                ))
            }
        }

        enqueue(root)
        while visited.count < allNodeIDs.count, let best = candidates.popMaximum() {
            guard !visited.contains(best.child), visited.contains(best.parent) else { continue }
            depths[best.child] = (depths[best.parent] ?? 0) + 1
            parentByID[best.child] = best.parent
            primaryLinkIndices.insert(best.index)
            visited.insert(best.child)
            enqueue(best.child)
        }
        return SpanningTree(
            depths: depths,
            primaryLinkIndices: primaryLinkIndices,
            parentByID: parentByID
        )
    }

    private struct SpanningTreeCandidate: Comparable {
        let index: Int
        let parent: String
        let child: String
        let quality: Int
        let relationshipPriority: Int

        static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.relationshipPriority != rhs.relationshipPriority {
                return lhs.relationshipPriority < rhs.relationshipPriority
            }
            if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
            if lhs.parent != rhs.parent { return lhs.parent > rhs.parent }
            if lhs.child != rhs.child { return lhs.child > rhs.child }
            return lhs.index > rhs.index
        }
    }

    private struct MaxHeap<Element: Comparable> {
        private var elements: [Element] = []

        mutating func insert(_ element: Element) {
            elements.append(element)
            siftUp(from: elements.count - 1)
        }

        mutating func popMaximum() -> Element? {
            guard !elements.isEmpty else { return nil }
            if elements.count == 1 { return elements.removeLast() }
            elements.swapAt(0, elements.count - 1)
            let result = elements.removeLast()
            siftDown(from: 0)
            return result
        }

        private mutating func siftUp(from index: Int) {
            var child = index
            while child > 0 {
                let parent = (child - 1) / 2
                guard elements[parent] < elements[child] else { break }
                elements.swapAt(parent, child)
                child = parent
            }
        }

        private mutating func siftDown(from index: Int) {
            var parent = index
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var candidate = parent
                if left < elements.count, elements[candidate] < elements[left] { candidate = left }
                if right < elements.count, elements[candidate] < elements[right] { candidate = right }
                guard candidate != parent else { break }
                elements.swapAt(parent, candidate)
                parent = candidate
            }
        }
    }

    private static func forceDirectedPositions(
        nodes: [NetworkTopologyNode],
        tree: SpanningTree,
        width: CGFloat,
        minimumHeight: CGFloat
    ) -> (positions: [String: CGPoint], contentSize: CGSize) {
        let ordered = nodes.sorted(by: nodeOrder)
        let nodeIndex = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1.id, $0) })
        let coordinatorIndex = ordered.firstIndex(where: { $0.role == .coordinator }) ?? 0
        let count = max(ordered.count, 1)
        let preferredDistance = DesignTokens.Size.networkMapPreferredLinkDistance
        let initialSpread = sqrt(CGFloat(count)) * preferredDistance

        // Seed every routing subtree in its own direction from its parent so
        // related devices start (and therefore stay) together, then let the
        // force pass relax it into an organic shape. Seeds are deterministic,
        // so node movement between refreshes means a topology change rather
        // than visual jitter.
        let seeded = subtreeSeeds(
            root: ordered[coordinatorIndex].id,
            tree: tree,
            ordered: ordered,
            spacing: preferredDistance
        )
        var positions = ordered.enumerated().map { index, node -> CGPoint in
            guard index != coordinatorIndex else { return .zero }
            if let seed = seeded[node.id] { return seed }
            // Devices without a known route sit on an outer ring.
            let seed = deterministicUnit(for: node.id)
            let angle = CGFloat(index) * 2.399_963_23 + seed * 0.7
            let radius = initialSpread * (1 + seed * 0.3)
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        var velocities = Array(repeating: CGVector.zero, count: ordered.count)

        let primaryPairs = tree.parentByID.compactMap { child, parent -> (Int, Int)? in
            guard let parentIndex = nodeIndex[parent], let childIndex = nodeIndex[child] else { return nil }
            return (parentIndex, childIndex)
        }

        let iterationCount = count > 260
            ? DesignTokens.Size.networkMapLargeLayoutIterations
            : DesignTokens.Size.networkMapLayoutIterations
        for iteration in 0..<iterationCount {
            var forces = Array(repeating: CGVector.zero, count: ordered.count)
            let cooling = 1 - CGFloat(iteration) / CGFloat(iterationCount + 1)

            // Repulsion spreads clusters out; exact non-overlap is enforced
            // afterwards by the footprint pass. This runs only during
            // background layout, never while the user pans or zooms the map.
            if count > 1 {
                for left in 0..<(count - 1) {
                    for right in (left + 1)..<count {
                        var dx = positions[right].x - positions[left].x
                        var dy = positions[right].y - positions[left].y
                        var squaredDistance = dx * dx + dy * dy
                        if squaredDistance < 0.01 {
                            dx = CGFloat((right - left) % 3 + 1)
                            dy = CGFloat((right + left) % 5 + 1)
                            squaredDistance = dx * dx + dy * dy
                        }
                        let distance = sqrt(squaredDistance)
                        let unitX = dx / distance
                        let unitY = dy / distance
                        let force = DesignTokens.Size.networkMapRepulsion / squaredDistance
                        forces[left].dx -= unitX * force
                        forces[left].dy -= unitY * force
                        forces[right].dx += unitX * force
                        forces[right].dy += unitY * force
                    }
                }
            }

            applySprings(
                pairs: primaryPairs,
                preferredDistance: preferredDistance,
                strength: DesignTokens.Size.networkMapPrimarySpringStrength,
                positions: positions,
                forces: &forces
            )

            for index in positions.indices where index != coordinatorIndex {
                let centrality = ordered[index].role == .router
                    ? DesignTokens.Size.networkMapRouterGravity
                    : DesignTokens.Size.networkMapEndDeviceGravity
                forces[index].dx -= positions[index].x * centrality
                forces[index].dy -= positions[index].y * centrality
                velocities[index].dx = (velocities[index].dx + forces[index].dx) * DesignTokens.Size.networkMapVelocityDamping
                velocities[index].dy = (velocities[index].dy + forces[index].dy) * DesignTokens.Size.networkMapVelocityDamping
                let maximumStep = DesignTokens.Size.networkMapMaximumLayoutStep * cooling
                let stepLength = hypot(velocities[index].dx, velocities[index].dy)
                if stepLength > maximumStep, stepLength > 0 {
                    velocities[index].dx = velocities[index].dx / stepLength * maximumStep
                    velocities[index].dy = velocities[index].dy / stepLength * maximumStep
                }
                positions[index].x += velocities[index].dx
                positions[index].y += velocities[index].dy
            }
            positions[coordinatorIndex] = .zero
            velocities[coordinatorIndex] = .zero
        }

        // Heard-neighbor links deliberately don't pull on the layout: they
        // are noisy, change between scans, and collapse the map into a knot.
        let resolved = separateFootprints(positions: positions, nodes: ordered, pinnedIndex: coordinatorIndex)
        let rawPositions = Dictionary(uniqueKeysWithValues: ordered.indices.map { (ordered[$0].id, resolved[$0]) })
        let bounds = rawPositions.values.reduce(into: CGRect.null) { result, point in
            result = result.union(CGRect(origin: point, size: .zero))
        }
        let padding = DesignTokens.Size.networkMapContentPadding
        let contentWidth = max(width, bounds.width + padding * 2)
        let contentHeight = max(minimumHeight, bounds.height + padding * 2)
        let offset = CGPoint(x: padding - bounds.minX, y: padding - bounds.minY)
        return (
            positions: rawPositions.mapValues { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) },
            contentSize: CGSize(width: contentWidth, height: contentHeight)
        )
    }

    /// Gives each subtree an angular wedge sized by how many devices it
    /// carries, and places each node in the middle of its wedge one link
    /// further out than its parent.
    private static func subtreeSeeds(
        root: String,
        tree: SpanningTree,
        ordered: [NetworkTopologyNode],
        spacing: CGFloat
    ) -> [String: CGPoint] {
        let rank = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1.id, $0) })
        var children: [String: [String]] = [:]
        for (child, parent) in tree.parentByID {
            children[parent, default: []].append(child)
        }
        for key in children.keys {
            children[key]?.sort { (rank[$0] ?? 0) < (rank[$1] ?? 0) }
        }

        var subtreeSize: [String: Int] = [:]
        func size(of id: String) -> Int {
            if let cached = subtreeSize[id] { return cached }
            let total = 1 + (children[id] ?? []).reduce(0) { $0 + size(of: $1) }
            subtreeSize[id] = total
            return total
        }

        var seeds: [String: CGPoint] = [root: .zero]
        var stack: [(id: String, start: CGFloat, span: CGFloat, depth: Int)] = [(root, 0, 2 * .pi, 0)]
        while let (id, start, span, depth) = stack.popLast() {
            let kids = children[id] ?? []
            let total = CGFloat(kids.reduce(0) { $0 + size(of: $1) })
            var cursor = start
            for kid in kids {
                let share = span * CGFloat(size(of: kid)) / max(total, 1)
                let angle = cursor + share / 2
                let radius = CGFloat(depth + 1) * spacing * (0.9 + deterministicUnit(for: kid) * 0.25)
                seeds[kid] = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                stack.append((kid, cursor, share, depth + 1))
                cursor += share
            }
        }
        return seeds
    }

    /// Treats each node as the box its bubble and name label occupy and
    /// pushes boxes apart until none overlap. Positions stay bubble centres.
    private static func separateFootprints(
        positions: [CGPoint],
        nodes: [NetworkTopologyNode],
        pinnedIndex: Int
    ) -> [CGPoint] {
        let gap = DesignTokens.Size.networkMapFootprintGap
        let labelExtent = DesignTokens.Size.networkMapNodeLabelSpacing + DesignTokens.Size.networkMapNodeLabelHeight
        var footprints = zip(positions, nodes).map { position, node in
            let size = nodeSize(for: node.role)
            return NetworkMapCollisionResolver.Footprint(
                center: CGPoint(x: position.x, y: position.y + labelExtent / 2),
                halfSize: CGSize(
                    width: (max(size, DesignTokens.Size.networkMapNodeLabelWidth) + gap) / 2,
                    height: (size + labelExtent + gap) / 2
                )
            )
        }
        NetworkMapCollisionResolver.resolve(
            &footprints,
            pinnedIndex: pinnedIndex,
            maximumPasses: DesignTokens.Size.networkMapCollisionPasses
        )
        return footprints.map { CGPoint(x: $0.center.x, y: $0.center.y - labelExtent / 2) }
    }

    static func nodeSize(for role: NetworkTopologyNode.Role) -> CGFloat {
        switch role {
        case .coordinator: DesignTokens.Size.networkMapCoordinatorNode
        case .router: DesignTokens.Size.networkMapRouterNode
        case .endDevice, .unknown: DesignTokens.Size.networkMapEndDeviceNode
        }
    }

    private static func applySprings(
        pairs: [(Int, Int)],
        preferredDistance: CGFloat,
        strength: CGFloat,
        positions: [CGPoint],
        forces: inout [CGVector]
    ) {
        for (source, target) in pairs {
            let dx = positions[target].x - positions[source].x
            let dy = positions[target].y - positions[source].y
            let distance = max(hypot(dx, dy), 0.01)
            let force = (distance - preferredDistance) * strength
            let unitX = dx / distance
            let unitY = dy / distance
            forces[source].dx += unitX * force
            forces[source].dy += unitY * force
            forces[target].dx -= unitX * force
            forces[target].dy -= unitY * force
        }
    }

    private static func deterministicUnit(for identifier: String) -> CGFloat {
        var value: UInt64 = 1_469_598_103_934_665_603
        for byte in identifier.utf8 {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        return CGFloat(value % 10_000) / 10_000
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
