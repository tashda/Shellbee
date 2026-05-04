import SwiftUI

/// Small inline pill that surfaces which bridge a row originated from. Shows
/// only when the user has more than one connected bridge — single-bridge users
/// never see attribution clutter. Drop it into Device rows, Log rows, etc.
struct BridgeBadge: View {
    let bridgeID: UUID
    let bridgeName: String

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.registry.sessions.values.filter(\.isConnected).count >= 2 {
            HStack(spacing: 3) {
                Circle()
                    .fill(BridgeColor.color(for: bridgeID))
                    .frame(width: 5, height: 5)
                Text(bridgeName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(BridgeColor.color(for: bridgeID).opacity(0.16))
            )
            .foregroundStyle(BridgeColor.color(for: bridgeID))
            .accessibilityLabel("Bridge: \(bridgeName)")
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        BridgeBadge(bridgeID: UUID(), bridgeName: "Main")
        BridgeBadge(bridgeID: UUID(), bridgeName: "Lab")
    }
    .padding()
    .environment(AppEnvironment())
}
