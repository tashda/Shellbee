import SwiftUI

struct HomeCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity), radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }
}

struct HomeStatCell: View {
    let value: String
    let label: String
    var valueColor: Color = .primary
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HomeCardDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct HomeCardAlertRow: View {
    let symbol: String
    let title: String
    let color: Color
    let action: (() -> Void)?

    var body: some View {
        SwiftUI.Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(HomeAlertButtonStyle(color: color))
            } else {
                label
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(DesignTokens.Opacity.chipFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
            }
        }
    }

    private var label: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: DesignTokens.Size.summaryRowTrailingIcon)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct StatCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1, anchor: .leading)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}

private struct HomeAlertButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                color.opacity(configuration.isPressed ? DesignTokens.Opacity.softFill : DesignTokens.Opacity.chipFill),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
            )
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}
