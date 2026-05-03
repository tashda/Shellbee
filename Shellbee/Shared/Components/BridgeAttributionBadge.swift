import SwiftUI

struct BridgeAttributionBadge: View {
    let bridgeID: UUID
    let bridgeName: String

    var body: some View {
        let tint = DesignTokens.Bridge.color(for: bridgeID)
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(bridgeName)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .foregroundStyle(tint)
        .accessibilityLabel("Bridge: \(bridgeName)")
    }
}
