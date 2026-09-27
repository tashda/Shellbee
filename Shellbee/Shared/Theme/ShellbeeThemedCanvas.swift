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
                .tint(palette.accent)
                .scrollContentBackground(.hidden)
                .background { ShellbeeThemeCanvas(palette: palette).ignoresSafeArea() }
        } else if let fallback {
            content.background(fallback.ignoresSafeArea())
        } else {
            content
        }
    }
}

/// The row and card colour: the theme's surface, or the system's grouped
/// secondary background when no theme is chosen. Use it anywhere a view
/// would reach for `secondarySystemGroupedBackground`.
nonisolated struct ShellbeeSurfaceStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let color = environment.shellbeeTheme.palette?.surface ?? Color(.secondarySystemGroupedBackground)
        return color.resolve(in: environment)
    }
}

extension ShapeStyle where Self == ShellbeeSurfaceStyle {
    static var shellbeeSurface: ShellbeeSurfaceStyle { ShellbeeSurfaceStyle() }
}

private struct ShellbeeThemedRows: ViewModifier {
    @Environment(\.shellbeeTheme) private var theme

    func body(content: Content) -> some View {
        if theme.palette != nil {
            content.listRowBackground(Rectangle().fill(.shellbeeSurface))
        } else {
            content
        }
    }
}

extension View {
    /// Paints every row inside a `List`/`Form` with the theme surface. Apply
    /// to the list's content (a `SwiftUI.Group` around its sections), since
    /// row backgrounds can't be set from outside the list. Rows that set
    /// their own `listRowBackground` keep it.
    func shellbeeThemedRows() -> some View {
        modifier(ShellbeeThemedRows())
    }

    /// Apply once to every screen root: `List`, `Form`, `ScrollView` or a
    /// sheet's content. It paints the canvas and tints the content with the
    /// theme accent; apply it before `.toolbar` so bar buttons keep the
    /// system tint. Screens that paint their own grouped background pass it
    /// as `fallback` so the standard theme looks exactly as before.
    func shellbeeThemedCanvas(fallback: Color? = nil) -> some View {
        modifier(ShellbeeThemedCanvas(fallback: fallback))
    }
}
