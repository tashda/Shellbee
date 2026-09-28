import SwiftUI

/// The activity accessory while a bridge reconnects, after returning from
/// the background or during a pull to refresh: what's on screen is from
/// before, and this says fresh data is on its way.
@available(iOS 26.0, *)
struct ActivityAccessoryUpdating: View {
    let bridgeName: String
    let isInline: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .frame(width: DesignTokens.ActivityFeed.accessoryArtwork,
                       height: DesignTokens.ActivityFeed.accessoryArtwork)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("Updating")
                    .font(.footnote.weight(.semibold))
                if !isInline {
                    Text(bridgeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: isInline ? nil : .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Updating \(bridgeName)")
    }
}
