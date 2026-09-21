import SwiftUI

/// One raw log line, drawn as a slice of its minute's card so the list can
/// stay lazy even when a minute holds hundreds of lines.
struct RawLogRow: View {
    enum Position {
        case only, first, middle, last

        init(index: Int, count: Int) {
            switch (index, count) {
            case (_, 1): self = .only
            case (0, _): self = .first
            case (count - 1, _): self = .last
            default: self = .middle
            }
        }
    }

    let entry: LogEntry
    let position: Position

    var body: some View {
        let content = RawLogLineContent(entry: entry)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                if let severity = RawLogSeverity(level: entry.level) {
                    Image(systemName: severity.systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(severity.tint)
                        .accessibilityLabel(entry.level.label)
                }
                Text(content.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let tag = content.tag {
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .background(.fill.tertiary, in: .rect(cornerRadius: DesignTokens.RawLog.tagCornerRadius))
                }
                Spacer(minLength: 0)
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Text(content.message)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(entry.level == .error ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .lineLimit(2)
        }
        .padding(.vertical, DesignTokens.RawLog.rowVerticalPadding)
        .overlay(alignment: .bottom) {
            if position == .first || position == .middle {
                Divider()
            }
        }
        .padding(.leading, DesignTokens.ActivityFeed.cardHorizontalPadding)
        .padding(.trailing, DesignTokens.ActivityFeed.cardHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: shape)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
    }

    private var shape: UnevenRoundedRectangle {
        let radius = DesignTokens.ActivityFeed.cardCornerRadius
        let top: CGFloat = position == .only || position == .first ? radius : 0
        let bottom: CGFloat = position == .only || position == .last ? radius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top
        )
    }
}

/// Only warnings and errors are marked: every other line is routine, so a
/// mark on each of them would say nothing.
private struct RawLogSeverity {
    let systemImage: String
    let tint: Color

    init?(level: LogLevel) {
        switch level {
        case .error:
            systemImage = "xmark.octagon.fill"
            tint = .red
        case .warning:
            systemImage = "exclamationmark.triangle.fill"
            tint = .orange
        case .info, .debug:
            return nil
        }
    }
}
