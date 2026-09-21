import SwiftUI

/// Shared visual primitives keep every Live Activity in the same visual
/// language. ActivityKit owns the surrounding surface; these views only
/// provide the content that belongs inside it.
struct LiveActivityStatusMark: View {
    let symbol: String
    let color: Color
    var size: CGFloat = DesignTokens.Size.liveActivityIslandSymbol

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct LiveActivityTitleBlock: View {
    let title: String
    let subtitle: String
    var tertiary: String? = nil
    var titleFont: Font = .headline

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .font(titleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let tertiary, !tertiary.isEmpty {
                Text(tertiary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The system supplies the Lock Screen activity surface and its outer insets.
/// Keep content compact so the activity stays within Apple's standard height.
struct LiveActivityLockScreenContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

struct LiveActivityMetric: View {
    let value: String
    var label: String? = nil
    let color: Color
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
            Text(value)
                .font((compact ? Font.caption : Font.title3).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let label, !compact {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct LiveActivityProgress: View {
    let progress: Int
    let tint: Color

    var body: some View {
        ProgressView(value: Double(progress), total: 100)
            .progressViewStyle(.linear)
            .tint(tint)
            .accessibilityValue("\(progress) percent")
    }
}

/// Secondary bridge context belongs below the primary operation in an
/// expanded Dynamic Island. Keeping it out of the center region preserves
/// room for the operation name and its trailing timer or metric.
struct LiveActivityBridgeContext: View {
    let name: String

    var body: some View {
        if !name.isEmpty {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
