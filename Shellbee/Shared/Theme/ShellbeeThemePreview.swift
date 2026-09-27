import SwiftUI

/// A still miniature of a themed screen: the canvas and glow, a card in the
/// surface colour with a device and a status line, and the accent on the
/// device's glyph. It shows no controls, so it doesn't read as something to
/// tap. Follows the current light or dark appearance and Card Tint.
struct ShellbeeThemePreview: View {
    let theme: ShellbeeTheme

    // The system blue rather than `.accentColor`, which follows the tint of
    // whichever theme is currently applied.
    private var accent: Color { theme.palette?.accent ?? Color(.systemBlue) }

    var body: some View {
        ZStack(alignment: .bottom) {
            canvas
            VStack(spacing: .zero) {
                row(symbol: "lightbulb.fill", symbolStyle: AnyShapeStyle(accent),
                    title: "Living Room", value: "80 %", valueStyle: AnyShapeStyle(.secondary))
                Divider()
                    .padding(.leading, DesignTokens.Theme.previewDividerInset)
                row(symbol: "wifi", symbolStyle: AnyShapeStyle(.status(.good)),
                    title: "Link quality", value: "142", valueStyle: AnyShapeStyle(.status(.good)))
            }
            .background(
                .shellbeeSurface,
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
            )
            .padding(DesignTokens.Spacing.md)
        }
        .environment(\.shellbeeTheme, theme)
        .frame(height: DesignTokens.Theme.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func row(symbol: String, symbolStyle: AnyShapeStyle, title: String,
                     value: String, valueStyle: AnyShapeStyle) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(symbolStyle)
                .frame(width: DesignTokens.Theme.previewSymbolWidth)
            Text(title)
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(value)
                .foregroundStyle(valueStyle)
                .monospacedDigit()
        }
        .font(.footnote)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.Theme.previewRowHeight)
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
