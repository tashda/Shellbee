import SwiftUI
import UIKit

/// An optional colour identity layered over the system look. A theme only
/// supplies a canvas, a soft glow at the top of it and an accent. Rows,
/// cards and text keep their system colours, so every list, form, sheet and
/// card stays legible without per-screen tuning. `.system` changes nothing.
nonisolated enum ShellbeeTheme: String, CaseIterable, Codable, Sendable {
    case system
    case honey
    case meadow
    case harbor
    case lavender
    case ember

    static let storageKey = "appearance.theme"
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
        case .honey: Palette(canvas: (0xF7F1E3, 0x100C06), accent: (0xA8660C, 0xF4B63F))
        case .meadow: Palette(canvas: (0xEEF3EA, 0x090E0A), accent: (0x3B7A4B, 0x7FCB93))
        case .harbor: Palette(canvas: (0xEAF1F5, 0x070D13), accent: (0x1D6A8A, 0x66BCE0))
        case .lavender: Palette(canvas: (0xF2EFF7, 0x0E0B15), accent: (0x6650B0, 0xB6A5F2))
        case .ember: Palette(canvas: (0xF7EEE8, 0x120B08), accent: (0xB0503A, 0xF08F71))
        }
    }

    struct Palette: Sendable {
        let canvas: Color
        let accent: Color

        init(canvas: (light: UInt32, dark: UInt32), accent: (light: UInt32, dark: UInt32)) {
            self.canvas = Self.dynamic(canvas)
            self.accent = Self.dynamic(accent)
        }

        private static func dynamic(_ hex: (light: UInt32, dark: UInt32)) -> Color {
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

private struct ShellbeeThemeKey: EnvironmentKey {
    static let defaultValue: ShellbeeTheme = .defaultTheme
}

extension EnvironmentValues {
    var shellbeeTheme: ShellbeeTheme {
        get { self[ShellbeeThemeKey.self] }
        set { self[ShellbeeThemeKey.self] = newValue }
    }
}
