import SwiftUI

/// Compact identity row, like an account or contact row in Settings: the
/// image, the full name, a readable description and a chevron. A status
/// only appears when it needs attention.
struct IdentityRow<Artwork: View>: View {
    let name: String
    let subtitle: String
    var bridgeID: UUID? = nil
    var bridgeName: String? = nil
    var status: DeviceStatus? = nil
    var showsChevron: Bool = true
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            artwork()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let bridgeID, let bridgeName, !bridgeName.isEmpty {
                    BridgeAttributionBadge(bridgeID: bridgeID, bridgeName: bridgeName)
                        .padding(.top, DesignTokens.Spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let status, status.needsAttention {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Circle()
                        .fill(status.color)
                        .frame(width: DesignTokens.Size.statusDotHero, height: DesignTokens.Size.statusDotHero)
                    Text(status.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardSurface(padding: DesignTokens.Spacing.md)
    }
}

#Preview {
    VStack {
        IdentityRow(name: "bathroom_ff_ceiling_lamp", subtitle: "Philips · Hue Devere ceiling light") {
            Image(systemName: "lightbulb.fill").font(.title)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
