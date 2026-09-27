import SwiftUI

/// A miniature settings screen in the theme: its canvas and glow, a system
/// row and the accent on a toggle and a bar. Follows the current light or
/// dark appearance.
struct ShellbeeThemePreview: View {
    let theme: ShellbeeTheme

    private var accent: Color { theme.palette?.accent ?? .accentColor }

    var body: some View {
        ZStack(alignment: .bottom) {
            canvas
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(accent)
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(accent.opacity(DesignTokens.Opacity.chipFill))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(accent)
                            .frame(width: DesignTokens.Theme.previewBarFill)
                    }
                    .frame(width: DesignTokens.Theme.previewBarWidth,
                           height: DesignTokens.Theme.previewBarHeight)
                Spacer()
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .tint(accent)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Theme.previewRowHeight)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
            )
            .padding(DesignTokens.Spacing.md)
        }
        .frame(height: DesignTokens.Theme.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var canvas: some View {
        if let palette = theme.palette {
            ShellbeeThemeCanvas(palette: palette)
        } else {
            Color(.systemGroupedBackground)
        }
    }
}
