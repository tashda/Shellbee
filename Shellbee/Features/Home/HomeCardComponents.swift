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

struct HomeCardTitle: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
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
                    .buttonStyle(HomeAlertButtonStyle())
            } else {
                label
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var label: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: DesignTokens.Size.summaryRowTrailingIcon)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct HomeCardAlertList<Content: View>: View {
    @ViewBuilder let rows: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            _VariadicView.Tree(DividerLayout()) { rows() }
        }
        .padding(.bottom, -DesignTokens.Spacing.sm)
    }
}

private struct DividerLayout: _VariadicView.MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        ForEach(children) { child in
            child
            if child.id != last {
                Divider().padding(.leading, DesignTokens.Size.summaryRowTrailingIcon + DesignTokens.Spacing.md)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: DesignTokens.Duration.pressedState), value: configuration.isPressed)
    }
}
