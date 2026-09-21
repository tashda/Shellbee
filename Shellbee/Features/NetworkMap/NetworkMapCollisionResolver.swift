import CoreGraphics

/// Pushes overlapping node footprints (bubble + name label) apart after the
/// force simulation has settled. Forces alone only make overlap unlikely;
/// this pass makes it impossible, so every name stays readable no matter how
/// many devices share one parent.
///
/// Each overlapping pair is separated along the line between their centres
/// rather than along an axis, which keeps the organic shape of the force
/// layout instead of snapping clusters into rows or columns.
nonisolated enum NetworkMapCollisionResolver {
    struct Footprint: Equatable {
        var center: CGPoint
        let halfSize: CGSize
    }

    static func resolve(
        _ footprints: inout [Footprint],
        pinnedIndex: Int?,
        maximumPasses: Int
    ) {
        guard footprints.count > 1 else { return }
        for _ in 0..<maximumPasses {
            if !resolvePass(&footprints, pinnedIndex: pinnedIndex) { return }
        }
    }

    /// One sweep-and-prune pass: sort by left edge, then only compare boxes
    /// whose horizontal extents overlap. Returns whether anything moved.
    private static func resolvePass(_ footprints: inout [Footprint], pinnedIndex: Int?) -> Bool {
        let order = footprints.indices.sorted { lhs, rhs in
            let left = footprints[lhs].center.x - footprints[lhs].halfSize.width
            let right = footprints[rhs].center.x - footprints[rhs].halfSize.width
            return left == right ? lhs < rhs : left < right
        }
        var moved = false
        for (position, first) in order.enumerated() {
            for second in order[(position + 1)...] {
                let a = footprints[first]
                let b = footprints[second]
                let requiredX = a.halfSize.width + b.halfSize.width
                // Sorted by left edge: once `b` starts past `a`'s right edge,
                // no later box can overlap `a` either.
                if (b.center.x - b.halfSize.width) >= (a.center.x + a.halfSize.width) { break }
                let requiredY = a.halfSize.height + b.halfSize.height
                var dx = b.center.x - a.center.x
                var dy = b.center.y - a.center.y
                guard abs(dx) < requiredX, abs(dy) < requiredY else { continue }

                if abs(dx) < 0.01, abs(dy) < 0.01 {
                    // Coincident centres: pick a stable direction per pair.
                    let angle = CGFloat((first * 31 + second * 17) % 360) * .pi / 180
                    dx = cos(angle)
                    dy = sin(angle)
                }
                let length = hypot(dx, dy)
                let unitX = dx / length
                let unitY = dy / length
                // Distance along the centre line needed to clear either axis,
                // plus a hair so the pair doesn't re-collide from rounding.
                let clearX = abs(unitX) > 0.001 ? (requiredX - abs(dx)) / abs(unitX) : .greatestFiniteMagnitude
                let clearY = abs(unitY) > 0.001 ? (requiredY - abs(dy)) / abs(unitY) : .greatestFiniteMagnitude
                let push = min(clearX, clearY) + 0.5

                let firstShare: CGFloat
                let secondShare: CGFloat
                switch pinnedIndex {
                case first: (firstShare, secondShare) = (0, 1)
                case second: (firstShare, secondShare) = (1, 0)
                default: (firstShare, secondShare) = (0.5, 0.5)
                }
                footprints[first].center.x -= unitX * push * firstShare
                footprints[first].center.y -= unitY * push * firstShare
                footprints[second].center.x += unitX * push * secondShare
                footprints[second].center.y += unitY * push * secondShare
                moved = true
            }
        }
        return moved
    }
}
