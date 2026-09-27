import SwiftUI

/// The themed backdrop: the palette's canvas with the accent glowing softly
/// from the top edge, fading out before the content gets busy.
struct ShellbeeThemeCanvas: View {
    let palette: ShellbeeTheme.Palette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        palette.canvas
            .overlay {
                LinearGradient(
                    colors: [palette.accent.opacity(glowOpacity), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: DesignTokens.Theme.glowHeightFraction)
                )
            }
    }

    private var glowOpacity: Double {
        colorScheme == .dark ? DesignTokens.Theme.glowOpacityDark : DesignTokens.Theme.glowOpacityLight
    }
}

private struct ShellbeeThemedCanvas: ViewModifier {
    /// What the screen paints when no theme is chosen. `nil` leaves a
    /// `List`/`Form` on its own system background.
    let fallback: Color?

    @Environment(\.shellbeeTheme) private var theme

    func body(content: Content) -> some View {
        if let palette = theme.palette {
            content
                .scrollContentBackground(.hidden)
                .background { ShellbeeThemeCanvas(palette: palette).ignoresSafeArea() }
        } else if let fallback {
            content.background(fallback.ignoresSafeArea())
        } else {
            content
        }
    }
}

extension View {
    /// Apply once to every screen root: `List`, `Form`, `ScrollView` or a
    /// sheet's content. Screens that paint their own grouped background pass
    /// it as `fallback` so the standard theme looks exactly as before.
    func shellbeeThemedCanvas(fallback: Color? = nil) -> some View {
        modifier(ShellbeeThemedCanvas(fallback: fallback))
    }
}
