import SwiftUI
import UIKit

/// The app's look, carried inside each Live Activity's content so the widget
/// extension draws it the same way. The extension can't read the app's
/// settings, so the app stamps them on every update; a theme change reaches
/// a running activity with its next update.
nonisolated struct LiveActivityAppearance: Codable, Hashable, Sendable {
    var theme: ShellbeeTheme
    /// Card Tint, 0…1: how far the card leans toward the theme.
    var surfaceTint: Double
    /// Themed Indicators: success, failure and working colours come from
    /// the theme too.
    var themesIndicators: Bool

    static let standard = Self(theme: .system, surfaceTint: ShellbeeTheme.defaultSurfaceTint, themesIndicators: false)

    /// The app's current settings. Only meaningful inside the app.
    static var current: Self {
        let defaults = UserDefaults.standard
        return Self(
            theme: ShellbeeTheme.stored(defaults.string(forKey: ShellbeeTheme.storageKey) ?? ""),
            surfaceTint: defaults.object(forKey: ShellbeeTheme.surfaceTintKey) as? Double ?? ShellbeeTheme.defaultSurfaceTint,
            themesIndicators: defaults.bool(forKey: StatusTone.themedStorageKey)
        )
    }

    /// The colour an activity should draw for one of `LiveActivityPalette`'s:
    /// an activity's own colour becomes the theme accent, and status colours
    /// follow Themed Indicators. Standard returns every colour unchanged.
    func resolve(_ color: Color) -> Color {
        if themesIndicators, let tone = Self.statusTones[color], let themed = theme.statusColor(tone) {
            return themed
        }
        if let palette = theme.palette, Self.identityColors.contains(color) {
            return palette.accent
        }
        return color
    }

    /// The card's gradient stops, top-leading to bottom-trailing. A theme
    /// warms the graphite and indigo toward its accent by the Card Tint.
    var cardStops: [Gradient.Stop] {
        guard let accent = theme.palette?.accent else {
            return [
                .init(color: LiveActivityPalette.cardGraphite, location: 0),
                .init(color: LiveActivityPalette.cardIndigo, location: 0.55),
                .init(color: LiveActivityPalette.cardNight, location: 1)
            ]
        }
        let amount = min(max(surfaceTint, 0), 1)
        return [
            .init(color: Self.blend(LiveActivityPalette.cardGraphite, accent, Self.topBlend(amount)), location: 0),
            .init(color: Self.blend(LiveActivityPalette.cardNight, accent, Self.middleBlend(amount)), location: 0.55),
            .init(color: LiveActivityPalette.cardNight, location: 1)
        ]
    }

    /// `base` moved `amount` of the way to `other`, using `other`'s dark
    /// variant since the card is always dark.
    private static func blend(_ base: Color, _ other: Color, _ amount: Double) -> Color {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(base).resolvedColor(with: dark).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).resolvedColor(with: dark).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(amount)
        return Color(red: Double(r1 + (r2 - r1) * t), green: Double(g1 + (g2 - g1) * t), blue: Double(b1 + (b2 - b1) * t))
    }

    private static func topBlend(_ amount: Double) -> Double { 0.12 + 0.28 * amount }
    private static func middleBlend(_ amount: Double) -> Double { 0.08 + 0.2 * amount }

    /// Colours that identify an activity rather than report a state.
    private static let identityColors: Set<Color> = [
        LiveActivityPalette.pairing,
        LiveActivityPalette.update,
        LiveActivityPalette.scan,
        LiveActivityPalette.identify
    ]

    private static let statusTones: [Color: StatusTone] = [
        LiveActivityPalette.success: .excellent,
        LiveActivityPalette.failure: .poor,
        LiveActivityPalette.working: .fair
    ]
}

extension LiveActivityLayout {
    /// This layout drawn in `appearance`; `nil` (content from before themes
    /// reached Live Activities) draws Standard.
    func themed(_ appearance: LiveActivityAppearance?) -> Self {
        let appearance = appearance ?? .standard
        var layout = self
        layout.tint = appearance.resolve(tint)
        layout.titleTint = titleTint.map(appearance.resolve)
        layout.compactTint = compactTint.map(appearance.resolve)
        layout.appearance = appearance
        return layout
    }
}
