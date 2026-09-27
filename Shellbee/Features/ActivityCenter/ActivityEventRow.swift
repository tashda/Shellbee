import SwiftUI

/// The inside of every Activity event, wherever it appears: instrument,
/// who it's about, when, and what happened. The Activity card wraps it in
/// card chrome and Home's Recent Events lists it, so a change here lands
/// in both at once.
struct ActivityEventRow<Footer: View>: View {
    let instrument: ActivityInstrument
    let content: ActivityCardContent
    let timestamp: Date
    var instrumentSize: CGFloat
    var alignment: VerticalAlignment = .top
    /// The event's bridge, marked with its monogram beside the time.
    var bridgeID: UUID? = nil
    var bridgeName: String = ""
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        HStack(alignment: alignment, spacing: DesignTokens.Spacing.md) {
            ActivityInstrumentView(instrument: instrument, size: instrumentSize)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text(content.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if let bridgeID {
                            BridgeMonogram(bridgeID: bridgeID, bridgeName: bridgeName)
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + DesignTokens.Size.bridgeMonogramBaselineOffset }
                        }
                        ActivityRelativeTime(date: timestamp)
                    }
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
                footer()
            }
        }
    }
}

extension ActivityEventRow where Footer == EmptyView {
    init(
        instrument: ActivityInstrument,
        content: ActivityCardContent,
        timestamp: Date,
        instrumentSize: CGFloat,
        alignment: VerticalAlignment = .top,
        bridgeID: UUID? = nil,
        bridgeName: String = ""
    ) {
        self.init(
            instrument: instrument,
            content: content,
            timestamp: timestamp,
            instrumentSize: instrumentSize,
            alignment: alignment,
            bridgeID: bridgeID,
            bridgeName: bridgeName,
            footer: { EmptyView() }
        )
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
