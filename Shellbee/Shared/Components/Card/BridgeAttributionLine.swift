import SwiftUI

/// The bridge a compact identity row belongs to: its monogram and name.
/// Hidden when the Bridge Indicators setting hides bridge marks.
struct BridgeAttributionLine: View {
    let bridgeID: UUID
    let bridgeName: String

    @Environment(AppEnvironment.self) private var environment
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        if BridgeGradientMode.stored(indicatorModeRaw).showsIndicators(in: environment) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                BridgeMonogram(bridgeID: bridgeID, bridgeName: bridgeName)
                Text(bridgeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bridge: \(bridgeName)")
        }
    }
}
