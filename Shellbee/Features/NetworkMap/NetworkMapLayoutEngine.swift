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

/// Lays the mesh as a compact, deterministic routing tree. Each child stays
/// close to its parent in the next routing layer, while subtree ordering keeps
/// links legible and prevents branches from crossing. The result is structured
/// like a network diagram without becoming a rigid device grid.
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
        let positioning = hierarchicalPositions(
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
        var adjacency: [String: [(index: Int, neighbor: String, quality: Int)]] = [:]
        adjacency.reserveCapacity(nodes.count)
        for (index, link) in links.enumerated() {
            let quality = link.linkQuality ?? -1
            adjacency[link.sourceIEEEAddress, default: []].append(
                (index, link.targetIEEEAddress, quality)
            )
            adjacency[link.targetIEEEAddress, default: []].append(
                (index, link.sourceIEEEAddress, quality)
            )
        }

        var candidates = MaxHeap<SpanningTreeCandidate>()
        func enqueue(_ parent: String) {
            for edge in adjacency[parent] ?? [] where !visited.contains(edge.neighbor) {
                candidates.insert(.init(
                    index: edge.index,
                    parent: parent,
                    child: edge.neighbor,
                    quality: edge.quality
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

        static func < (lhs: Self, rhs: Self) -> Bool {
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

    private static func hierarchicalPositions(
        nodes: [NetworkTopologyNode],
        tree: SpanningTree,
        width: CGFloat,
        minimumHeight: CGFloat
    ) -> (positions: [String: CGPoint], contentSize: CGSize) {
        let nodeSpacing = DesignTokens.Size.networkMapMinimumNodeSpacing
        let depthGap = DesignTokens.Size.networkMapDepthSpacing
        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var childrenByParent: [String: [String]] = [:]

        for (child, parent) in tree.parentByID {
            childrenByParent[parent, default: []].append(child)
        }
        for parent in childrenByParent.keys {
            childrenByParent[parent]?.sort { lhs, rhs in
                guard let left = nodesByID[lhs], let right = nodesByID[rhs] else { return lhs < rhs }
                return nodeOrder(left, right)
            }
        }

        let roots = nodes
            .filter { tree.parentByID[$0.id] == nil }
            .sorted(by: nodeOrder)

        // Give every subtree one continuous vertical interval. Children are
        // placed in deterministic order inside that interval, which keeps the
        // routing tree readable without forcing devices into a global grid.
        var subtreeSpans: [String: CGFloat] = [:]
        func span(for id: String) -> CGFloat {
            if let cached = subtreeSpans[id] { return cached }
            let children = childrenByParent[id] ?? []
            let childSpans = children.map { span(for: $0) }
            let childTotal = childSpans.reduce(0, +)
                + CGFloat(max(children.count - 1, 0)) * nodeSpacing
            let result = max(nodeSpacing, childTotal)
            subtreeSpans[id] = result
            return result
        }

        var positions: [String: CGPoint] = [:]
        func place(_ id: String, depth: Int, minY: CGFloat) {
            let children = childrenByParent[id] ?? []
            let childSpans = children.map { span(for: $0) }
            let childTotal = childSpans.reduce(0, +)
                + CGFloat(max(children.count - 1, 0)) * nodeSpacing
            var childY = minY + (span(for: id) - childTotal) / 2
            var childCenters: [CGFloat] = []

            for (index, child) in children.enumerated() {
                let childSpan = childSpans[index]
                place(child, depth: depth + 1, minY: childY)
                childCenters.append(positions[child]?.y ?? childY + childSpan / 2)
                childY += childSpan + nodeSpacing
            }

            let centerY = childCenters.isEmpty
                ? minY + span(for: id) / 2
                : childCenters.reduce(0, +) / CGFloat(childCenters.count)
            positions[id] = CGPoint(x: CGFloat(depth) * depthGap, y: centerY)
        }

        var cursor: CGFloat = 0
        for root in roots {
            let rootSpan = span(for: root.id)
            place(root.id, depth: 0, minY: cursor)
            cursor += rootSpan + nodeSpacing * 1.5
        }

        let bounds = positions.values.reduce(into: CGRect.null) { result, point in
            result = result.union(CGRect(origin: point, size: .zero))
        }
        let padding = DesignTokens.Size.networkMapContentPadding
        let contentWidth = max(width, bounds.width + padding * 2)
        let contentHeight = max(minimumHeight, bounds.height + padding * 2)
        let offset = CGPoint(x: padding - bounds.minX, y: padding - bounds.minY)
        return (
            positions: positions.mapValues { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) },
            contentSize: CGSize(width: contentWidth, height: contentHeight)
        )
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
