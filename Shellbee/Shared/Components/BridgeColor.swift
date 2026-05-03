import SwiftUI

/// Deterministic color palette for bridge attribution. Each saved bridge id
/// hashes into a stable slot in the palette so the same bridge always renders
/// in the same color across launches and devices. Phase 2 multi-bridge UI uses
/// a small colored dot in row corners instead of a verbose badge.
enum BridgeColor {
    /// Distinct, accessible hues that read well as small dots on both
    /// light and dark backgrounds.
    static let palette: [Color] = [
        Color(red: 0.20, green: 0.56, blue: 0.87), // blue
        Color(red: 0.93, green: 0.39, blue: 0.32), // tomato
        Color(red: 0.31, green: 0.69, blue: 0.31), // green
        Color(red: 0.95, green: 0.63, blue: 0.20), // amber
        Color(red: 0.61, green: 0.36, blue: 0.85), // purple
        Color(red: 0.20, green: 0.74, blue: 0.74), // teal
        Color(red: 0.92, green: 0.46, blue: 0.65), // pink
        Color(red: 0.40, green: 0.50, blue: 0.30), // olive
    ]

    /// Resolve a stable color for the given bridge id by hashing into the
    /// palette. Same id → same color across launches.
    static func color(for bridgeID: UUID) -> Color {
        let bytes = withUnsafeBytes(of: bridgeID.uuid) { Array($0) }
        // Sum the bytes — UUID isn't Hashable in a stable cross-platform way,
        // and Swift's `hashValue` is randomised per process.
        let sum = bytes.reduce(0) { $0 &+ Int($1) }
        return palette[abs(sum) % palette.count]
    }
}

/// A small colored dot used in row corners to indicate a device/log/group's
/// source bridge. Auto-hides when only one bridge is connected (single-bridge
/// users see no clutter). Pair with `.help(bridgeName)` for accessibility.
struct BridgeColorDot: View {
    let bridgeID: UUID
    let bridgeName: String
    var size: CGFloat = 8

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.registry.sessions.values.filter(\.isConnected).count >= 2 {
            Circle()
                .fill(BridgeColor.color(for: bridgeID))
                .frame(width: size, height: size)
                .accessibilityLabel("Bridge: \(bridgeName)")
                .help(bridgeName)
        }
    }
}
