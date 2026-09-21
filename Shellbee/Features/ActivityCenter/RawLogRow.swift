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
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            RawLogLevelMark(level: entry.level)
                .padding(.top, DesignTokens.Spacing.xxs)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
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

/// Quiet grey dot for routine lines; solid orange or red with a white mark
/// for warnings and errors, so problems stand out in a busy stream.
private struct RawLogLevelMark: View {
    let level: LogLevel

    var body: some View {
        let size = DesignTokens.RawLog.levelMark
        switch level {
        case .error, .warning:
            Image(systemName: level == .error ? "xmark" : "exclamationmark")
                .font(.system(size: size * DesignTokens.RawLog.levelGlyphRatio, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(level == .error ? Color.red : Color.orange, in: Circle())
                .accessibilityLabel(level.label)
        case .info, .debug:
            Circle()
                .fill(level == .debug ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                .frame(width: DesignTokens.RawLog.quietDot, height: DesignTokens.RawLog.quietDot)
                .frame(width: size, height: size)
                .background(.fill.tertiary, in: Circle())
                .accessibilityLabel(level.label)
        }
    }
}
