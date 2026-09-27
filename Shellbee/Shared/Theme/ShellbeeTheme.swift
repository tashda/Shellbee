import SwiftUI
import UIKit

/// An optional colour identity layered over the system look. A theme
/// supplies a canvas with a soft glow at the top and an accent for content
/// controls; rows and cards blend toward it by the Card Tint setting. Text
/// keeps its system colours and toolbars keep the system tint. `.system`
/// changes nothing.
nonisolated enum ShellbeeTheme: String, CaseIterable, Codable, Sendable {
    case system
    case honey
    case meadow
    case harbor
    case lavender
    case ember

    static let storageKey = "appearance.theme"
    /// 0…1, how far rows and cards lean toward the theme.
    static let surfaceTintKey = "appearance.surfaceTint"
    static let defaultSurfaceTint = 0.5
    static let defaultTheme: Self = .system

    var displayName: String {
        switch self {
        case .system: "Standard"
        case .honey: "Honey"
        case .meadow: "Meadow"
        case .harbor: "Harbor"
        case .lavender: "Lavender"
        case .ember: "Ember"
        }
    }

    var summary: String {
        switch self {
        case .system: "System backgrounds and accent"
        case .honey: "Warm cream with an amber accent"
        case .meadow: "Soft sage with a leaf green accent"
        case .harbor: "Sea mist with a deep blue accent"
        case .lavender: "Pale lilac with a violet accent"
        case .ember: "Warm clay with a terracotta accent"
        }
    }

    static func stored(_ rawValue: String) -> Self {
        Self(rawValue: rawValue) ?? defaultTheme
    }

    /// The accent for places that need a concrete `Color` rather than `.tint`.
    var accent: Color { palette?.accent ?? .accentColor }

    /// `nil` for `.system`. Colours are dynamic, so they follow light and
    /// dark mode on their own.
    var palette: Palette? {
        switch self {
        case .system: nil
        case .honey: Palette(canvas: (0xF3EAD6, 0x100C06), accent: (0xA8660C, 0xF4B63F))
        case .meadow: Palette(canvas: (0xE9EFE3, 0x090E0A), accent: (0x3B7A4B, 0x7FCB93))
        case .harbor: Palette(canvas: (0xE3ECF2, 0x070D13), accent: (0x1D6A8A, 0x66BCE0))
        case .lavender: Palette(canvas: (0xEDE8F5, 0x0E0B15), accent: (0x6650B0, 0xB6A5F2))
        case .ember: Palette(canvas: (0xF3E6DE, 0x120B08), accent: (0xB0503A, 0xF08F71))
        }
    }

    struct Palette: Sendable {
        /// The screen background behind rows and cards. Rows and cards blend
        /// toward it by the Card Tint setting (see `ShellbeeSurfaceStyle`).
        let canvas: Color
        let accent: Color

        init(canvas: (light: UInt32, dark: UInt32), accent: (light: UInt32, dark: UInt32)) {
            self.canvas = Self.dynamic(canvas)
            self.accent = Self.dynamic(accent)
        }

        static func dynamic(_ hex: (light: UInt32, dark: UInt32)) -> Color {
            Color(uiColor: UIColor { traits in
                rgb(traits.userInterfaceStyle == .dark ? hex.dark : hex.light)
            })
        }

        private static func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
        }
    }
}

nonisolated private struct ShellbeeThemeKey: EnvironmentKey {
    static let defaultValue: ShellbeeTheme = .defaultTheme
}

nonisolated private struct ShellbeeSurfaceTintKey: EnvironmentKey {
    static let defaultValue = ShellbeeTheme.defaultSurfaceTint
}

extension EnvironmentValues {
    nonisolated var shellbeeTheme: ShellbeeTheme {
        get { self[ShellbeeThemeKey.self] }
        set { self[ShellbeeThemeKey.self] = newValue }
    }

    nonisolated var shellbeeSurfaceTint: Double {
        get { self[ShellbeeSurfaceTintKey.self] }
        set { self[ShellbeeSurfaceTintKey.self] = newValue }
    }
}
