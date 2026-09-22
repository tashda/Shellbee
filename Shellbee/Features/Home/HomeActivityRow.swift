import SwiftUI

/// A recent event on Home. The same row the Activity feed draws, in a
/// native List row rather than a card of its own — Home shows the last few
/// events, the Activity Center shows all of them, and both read the same.
struct HomeActivityRow: View {
    let item: ActivityEventItem

    @ScaledMetric(relativeTo: .subheadline) private var thumbnailSize = DesignTokens.ActivityFeed.thumbnail

    var body: some View {
        ActivityEventRow(
            instrument: item.instrument,
            content: item.content,
            timestamp: item.timestamp,
            instrumentSize: thumbnailSize
        )
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .contentShape(Rectangle())
    }
}
