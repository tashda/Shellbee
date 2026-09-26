import SwiftUI

/// Quiet bridge attribution for identity headers and linked rows.
struct BridgeAttributionLine: View {
    let bridgeID: UUID
    let bridgeName: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Circle()
                .fill(DesignTokens.Bridge.color(for: bridgeID))
                .frame(
                    width: DesignTokens.Size.statusDotHero,
                    height: DesignTokens.Size.statusDotHero
                )
            Text(bridgeName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bridge: \(bridgeName)")
    }
}
