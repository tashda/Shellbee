import SwiftUI
import WidgetKit

/// The Queue style: a header with the overall value, then one line per item
/// with its own small bar, like a download list.
struct LiveActivityQueueContent: View {
    let layout: LiveActivityLayout
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline) {
                    LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityTrackIcon, pulses: layout.isBusy)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                    Text(layout.title)
                        .font(.headline)
                        .foregroundStyle(layout.titleTint ?? .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    LiveActivityValueView(value: layout.value, tint: layout.tint, font: .title2.weight(.semibold))
                }
            }
            ForEach(layout.rows.prefix(DesignTokens.Count.liveActivityQueueRows)) { row in
                QueueRow(row: row, tint: layout.tint)
            }
            if layout.rows.count > DesignTokens.Count.liveActivityQueueRows {
                Text("\(layout.rows.count - DesignTokens.Count.liveActivityQueueRows) more waiting")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

private struct QueueRow: View {
    let row: LiveActivityRow
    let tint: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(row.name)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(row.fraction == nil ? 0.5 : 0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: DesignTokens.Size.liveActivityQueueName, alignment: .leading)
            Capsule()
                .fill(.white.opacity(0.14))
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * (row.fraction ?? 0))
                    }
                }
                .frame(height: DesignTokens.Size.liveActivityQueueBar)
            Text(row.status)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(row.fraction == nil ? .white.opacity(0.5) : tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .frame(width: DesignTokens.Size.liveActivityQueueStatus, alignment: .trailing)
        }
    }
}

/// The Spotlight style: one big centred value with the icon above it, like
/// a stopwatch. For short, single-purpose activities.
struct LiveActivitySpotlightContent: View {
    let layout: LiveActivityLayout
    var showsIcon = true

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if showsIcon {
                LiveActivityBadge(symbol: layout.symbol, tint: layout.tint, size: DesignTokens.Size.liveActivityBadge, pulses: layout.isBusy)
            }
            LiveActivityValueView(value: layout.value, tint: layout.tint, font: DesignTokens.Typography.liveActivityHeroValue)
            Text(layout.subtitle.map { "\(layout.title) · \($0)" } ?? layout.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(layout.titleTint ?? .white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            LiveActivityChunkyBar(gauge: layout.gauge, tint: layout.tint)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.top, DesignTokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
    }
}
