import SwiftUI

/// One notification-style card in the Activity feed.
struct ActivityCard: View {
    let instrument: ActivityInstrument
    let content: ActivityCardContent
    let timestamp: Date
    /// "13 more updates" on the top card of a collapsed stack.
    var moreText: String? = nil
    var bridgeID: UUID? = nil
    var bridgeName: String = ""
    @ScaledMetric(relativeTo: .subheadline) private var thumbnailSize = DesignTokens.ActivityFeed.thumbnail
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        ActivityEventRow(
            instrument: instrument,
            content: content,
            timestamp: timestamp,
            instrumentSize: thumbnailSize,
            bridgeID: bridgeID,
            bridgeName: bridgeName
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
            .shellbeeSurface,
            in: .rect(cornerRadius: DesignTokens.ActivityFeed.cardCornerRadius)
        )
        .contentShape(.rect(cornerRadius: DesignTokens.ActivityFeed.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// The card reads as one element, which hides the bridge monogram's own
    /// label, so the bridge is named here whenever the monogram is shown.
    private var accessibilityText: String {
        [content.title, content.message, content.detail, moreText, bridgeText]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var bridgeText: String? {
        guard bridgeID != nil,
              BridgeGradientMode.stored(indicatorModeRaw).showsIndicators(in: environment)
        else { return nil }
        return BridgeMonogram.accessibilityLabel(for: bridgeName)
    }
}

extension ActivityCard {
    init(entry: LogEntry, content: ActivityCardContent, moreText: String? = nil,
         bridgeID: UUID? = nil, bridgeName: String = "") {
        self.init(
            instrument: ActivityInstrumentResolver.instrument(for: entry),
            content: content,
            timestamp: entry.timestamp,
            moreText: moreText,
            bridgeID: bridgeID,
            bridgeName: bridgeName
        )
    }
}
