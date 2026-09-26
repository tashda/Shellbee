import SwiftUI

/// What the tab bar accessory draws, independent of where the data comes
/// from: the live accessory feeds it bridge events, the developer gallery
/// feeds it samples, so both show exactly the same surface.
struct ActivityAccessoryContent: View {
    let instrument: ActivityInstrument
    let title: String
    let subtitle: String?
    let change: ActivityAccessoryChange?
    /// When the event happened; nil for the Summary mode, which shows none.
    let timestamp: Date?
    /// Who reported the change; the trailing digits roll only within it.
    let identity: String
    let isInline: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ActivityInstrumentView(instrument: instrument, size: DesignTokens.ActivityFeed.accessoryArtwork)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                // The trailing value and its instrument already say what changed.
                if !isInline, change == nil, let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            if let timestamp {
                ActivityAccessoryTrailing(change: change, timestamp: timestamp, identity: identity, isInline: isInline)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: isInline ? nil : .infinity, alignment: .leading)
        .accessibilityLabel("Activity: \(title)")
        .accessibilityHint("Opens Activity")
    }
}
