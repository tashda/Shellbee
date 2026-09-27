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

/// The row and card colour. With no theme it's the system's grouped
/// secondary background. With a theme it blends from there toward the theme
/// by the Card Tint setting: toward the canvas in light mode, and toward the
/// accent in dark mode, where the canvas is darker than the card. Use it
/// anywhere a view would reach for `secondarySystemGroupedBackground`.
nonisolated struct ShellbeeSurfaceStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let base = Color(.secondarySystemGroupedBackground).resolve(in: environment)
        guard let palette = environment.shellbeeTheme.palette else { return base }
        let dark = environment.colorScheme == .dark
        let target = (dark ? palette.accent : palette.canvas).resolve(in: environment)
        let reach = dark ? DesignTokens.Theme.surfaceReachDark : DesignTokens.Theme.surfaceReachLight
        let amount = Float(environment.shellbeeSurfaceTint * reach)
        return Color.Resolved(
            red: base.red + (target.red - base.red) * amount,
            green: base.green + (target.green - base.green) * amount,
            blue: base.blue + (target.blue - base.blue) * amount,
            opacity: base.opacity
        )
    }
}

extension ShapeStyle where Self == ShellbeeSurfaceStyle {
    static var shellbeeSurface: ShellbeeSurfaceStyle { ShellbeeSurfaceStyle() }
}

/// The ink for monochrome charts (link quality bars, vendor rankings): the
/// primary label colour, or the theme accent when a theme is chosen. Vary
/// weight with `.opacity(_:)`.
nonisolated struct ShellbeeChartInkStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        (environment.shellbeeTheme.palette?.accent ?? .primary).resolve(in: environment)
    }
}

extension ShapeStyle where Self == ShellbeeChartInkStyle {
    static var shellbeeChartInk: ShellbeeChartInkStyle { ShellbeeChartInkStyle() }
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
