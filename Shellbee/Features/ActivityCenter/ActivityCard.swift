import SwiftUI

/// One notification-style card in the Activity feed.
struct ActivityCard: View {
    let entry: LogEntry
    let content: ActivityCardContent
    let store: AppStore?
    /// "13 more updates" on the top card of a collapsed stack.
    var moreText: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            ActivityThumbnail(entry: entry, store: store)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text(content.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    ActivityRelativeTime(date: entry.timestamp)
                }
                Text(content.message)
                    .font(.subheadline)
                    .lineLimit(2)
                if let detail = content.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let moreText {
                    Text(moreText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, DesignTokens.Spacing.xxs)
                }
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

/// "now", "2m ago", "1h ago", refreshed each minute, the way Notification
/// Center shows time.
struct ActivityRelativeTime: View {
    let date: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(label(now: context.date))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func label(now: Date) -> String {
        if now.timeIntervalSince(date) < 60 {
            return String(localized: "now")
        }
        return date.formatted(.relative(presentation: .named, unitsStyle: .narrow))
    }
}
