import SwiftUI

/// One notification-style card in the Activity feed.
struct ActivityCard: View {
    let instrument: ActivityInstrument
    let content: ActivityCardContent
    let timestamp: Date
    /// "13 more updates" on the top card of a collapsed stack.
    var moreText: String? = nil
    @ScaledMetric(relativeTo: .subheadline) private var thumbnailSize = DesignTokens.ActivityFeed.thumbnail

    var body: some View {
        ActivityEventRow(
            instrument: instrument,
            content: content,
            timestamp: timestamp,
            instrumentSize: thumbnailSize
        ) {
            if let moreText {
                Text(moreText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignTokens.Spacing.xxs)
            }
        }
        .padding(.horizontal, DesignTokens.ActivityFeed.cardHorizontalPadding)
        .padding(.vertical, DesignTokens.ActivityFeed.cardVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: .rect(cornerRadius: DesignTokens.ActivityFeed.cardCornerRadius)
        )
        .contentShape(.rect(cornerRadius: DesignTokens.ActivityFeed.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        [content.title, content.message, content.detail, moreText]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension ActivityCard {
    init(entry: LogEntry, content: ActivityCardContent, moreText: String? = nil) {
        self.init(
            instrument: ActivityInstrumentResolver.instrument(for: entry),
            content: content,
            timestamp: entry.timestamp,
            moreText: moreText
        )
    }
}
