import SwiftUI

/// A stored theme identity. For now themes only change Home's canvas; other
/// surfaces continue to use semantic system colors. New theme roles can be
/// resolved here without tying views to a particular palette.
nonisolated enum ShellbeeTheme: String, CaseIterable, Codable, Sendable {
    case system
    case sunriseGlow
    case livingNetwork
    case twilightLab
    case citrusGrove
    case oceanCurrent

    static let storageKey = "appearance.theme"
    static let defaultTheme: Self = .sunriseGlow

    var displayName: String {
        switch self {
        case .system: "System"
        case .sunriseGlow: "Sunrise glow"
        case .livingNetwork: "Living network"
        case .twilightLab: "Twilight lab"
        case .citrusGrove: "Citrus grove"
        case .oceanCurrent: "Ocean current"
        }
    }

    var summary: String {
        switch self {
        case .system: "The standard grouped background"
        case .sunriseGlow: "Peach and lilac light"
        case .livingNetwork: "Mint with a quiet network motif"
        case .twilightLab: "Indigo and violet depth"
        case .citrusGrove: "Lemon and fresh green"
        case .oceanCurrent: "Aqua and clear blue"
        }
    }

    static func stored(_ rawValue: String) -> Self {
        Self(rawValue: rawValue) ?? defaultTheme
    }

    func homeMeshColors(for colorScheme: ColorScheme) -> [Color]? {
        switch self {
        case .system:
            return nil
        case .sunriseGlow:
            return colorScheme == .dark ? Self.sunriseDark : Self.sunriseLight
        case .livingNetwork:
            return colorScheme == .dark ? Self.networkDark : Self.networkLight
        case .twilightLab:
            return colorScheme == .dark ? Self.twilightDark : Self.twilightLight
        case .citrusGrove:
            return colorScheme == .dark ? Self.citrusDark : Self.citrusLight
        case .oceanCurrent:
            return colorScheme == .dark ? Self.oceanDark : Self.oceanLight
        }
    }

    func accentColor(for colorScheme: ColorScheme) -> Color? {
        switch self {
        case .system: nil
        case .sunriseGlow:
            colorScheme == .dark
                ? Color(red: 0.72, green: 0.62, blue: 1.00)
                : Color(red: 0.40, green: 0.30, blue: 0.76)
        case .livingNetwork:
            colorScheme == .dark
                ? Color(red: 0.35, green: 0.85, blue: 0.81)
                : Color(red: 0.00, green: 0.50, blue: 0.54)
        case .twilightLab:
            colorScheme == .dark
                ? Color(red: 0.68, green: 0.58, blue: 1.00)
                : Color(red: 0.37, green: 0.31, blue: 0.72)
        case .citrusGrove:
            colorScheme == .dark
                ? Color(red: 0.76, green: 0.86, blue: 0.42)
                : Color(red: 0.40, green: 0.53, blue: 0.16)
        case .oceanCurrent:
            colorScheme == .dark
                ? Color(red: 0.48, green: 0.77, blue: 1.00)
                : Color(red: 0.10, green: 0.43, blue: 0.72)
        }
    }

    func motifColor(for colorScheme: ColorScheme) -> Color? {
        guard self == .livingNetwork else { return nil }
        return colorScheme == .dark
            ? Color(red: 0.38, green: 0.83, blue: 0.80)
            : Color(red: 0.13, green: 0.62, blue: 0.62)
    }

    var swatchColors: [Color] {
        switch self {
        case .system:
            [Color(.systemGroupedBackground), Color(.secondarySystemGroupedBackground)]
        case .sunriseGlow:
            [Self.sunriseLight[0], Self.sunriseLight[2], Self.sunriseLight[5]]
        case .livingNetwork:
            [Self.networkLight[0], Self.networkLight[4], Self.networkLight[8]]
        case .twilightLab:
            [Self.twilightLight[0], Self.twilightLight[4], Self.twilightLight[8]]
        case .citrusGrove:
            [Self.citrusLight[0], Self.citrusLight[4], Self.citrusLight[8]]
        case .oceanCurrent:
            [Self.oceanLight[0], Self.oceanLight[4], Self.oceanLight[8]]
        }
    }

    // Top to bottom, left to right. The lower row settles toward the
    // grouped canvas so long dashboards stay quiet behind their cards.
    private static let sunriseLight: [Color] = [
        Color(red: 1.00, green: 0.95, blue: 0.86),
        Color(red: 0.99, green: 0.91, blue: 0.90),
        Color(red: 0.94, green: 0.90, blue: 0.99),
        Color(red: 0.99, green: 0.94, blue: 0.93),
        Color(red: 0.96, green: 0.93, blue: 0.98),
        Color(red: 0.92, green: 0.94, blue: 1.00),
        Color(red: 0.98, green: 0.97, blue: 0.99),
        Color(red: 0.97, green: 0.97, blue: 0.99),
        Color(red: 0.97, green: 0.97, blue: 0.99),
    ]

    private static let sunriseDark: [Color] = [
        Color(red: 0.20, green: 0.15, blue: 0.18),
        Color(red: 0.23, green: 0.15, blue: 0.22),
        Color(red: 0.19, green: 0.15, blue: 0.27),
        Color(red: 0.17, green: 0.15, blue: 0.20),
        Color(red: 0.17, green: 0.15, blue: 0.23),
        Color(red: 0.15, green: 0.17, blue: 0.25),
        Color(red: 0.12, green: 0.12, blue: 0.15),
        Color(red: 0.12, green: 0.12, blue: 0.16),
        Color(red: 0.12, green: 0.12, blue: 0.16),
    ]

    private static let networkLight: [Color] = [
        Color(red: 0.85, green: 0.97, blue: 0.92),
        Color(red: 0.85, green: 0.97, blue: 0.96),
        Color(red: 0.89, green: 0.96, blue: 0.98),
        Color(red: 0.91, green: 0.98, blue: 0.94),
        Color(red: 0.91, green: 0.97, blue: 0.96),
        Color(red: 0.93, green: 0.97, blue: 0.98),
        Color(red: 0.97, green: 0.99, blue: 0.97),
        Color(red: 0.96, green: 0.99, blue: 0.98),
        Color(red: 0.97, green: 0.98, blue: 0.99),
    ]

    private static let networkDark: [Color] = [
        Color(red: 0.08, green: 0.20, blue: 0.19),
        Color(red: 0.08, green: 0.19, blue: 0.22),
        Color(red: 0.09, green: 0.17, blue: 0.23),
        Color(red: 0.09, green: 0.17, blue: 0.17),
        Color(red: 0.09, green: 0.16, blue: 0.19),
        Color(red: 0.10, green: 0.15, blue: 0.20),
        Color(red: 0.10, green: 0.13, blue: 0.14),
        Color(red: 0.10, green: 0.13, blue: 0.15),
        Color(red: 0.10, green: 0.12, blue: 0.16),
    ]

    private static let twilightLight: [Color] = [
        Color(red: 0.91, green: 0.87, blue: 0.98),
        Color(red: 0.89, green: 0.88, blue: 0.99),
        Color(red: 0.87, green: 0.91, blue: 1.00),
        Color(red: 0.94, green: 0.91, blue: 0.98),
        Color(red: 0.92, green: 0.92, blue: 0.99),
        Color(red: 0.91, green: 0.94, blue: 1.00),
        Color(red: 0.97, green: 0.96, blue: 0.99),
        Color(red: 0.96, green: 0.96, blue: 0.99),
        Color(red: 0.96, green: 0.97, blue: 0.99),
    ]

    private static let twilightDark: [Color] = [
        Color(red: 0.21, green: 0.15, blue: 0.34),
        Color(red: 0.17, green: 0.17, blue: 0.37),
        Color(red: 0.12, green: 0.21, blue: 0.36),
        Color(red: 0.16, green: 0.15, blue: 0.28),
        Color(red: 0.14, green: 0.16, blue: 0.30),
        Color(red: 0.11, green: 0.18, blue: 0.29),
        Color(red: 0.11, green: 0.11, blue: 0.19),
        Color(red: 0.10, green: 0.12, blue: 0.20),
        Color(red: 0.10, green: 0.13, blue: 0.20),
    ]

    private static let citrusLight: [Color] = [
        Color(red: 1.00, green: 0.97, blue: 0.80),
        Color(red: 0.96, green: 0.98, blue: 0.82),
        Color(red: 0.88, green: 0.97, blue: 0.85),
        Color(red: 1.00, green: 0.98, blue: 0.89),
        Color(red: 0.96, green: 0.98, blue: 0.88),
        Color(red: 0.91, green: 0.98, blue: 0.91),
        Color(red: 0.99, green: 0.99, blue: 0.96),
        Color(red: 0.97, green: 0.99, blue: 0.96),
        Color(red: 0.96, green: 0.99, blue: 0.97),
    ]

    private static let citrusDark: [Color] = [
        Color(red: 0.22, green: 0.19, blue: 0.10),
        Color(red: 0.19, green: 0.21, blue: 0.10),
        Color(red: 0.14, green: 0.20, blue: 0.12),
        Color(red: 0.19, green: 0.18, blue: 0.11),
        Color(red: 0.17, green: 0.19, blue: 0.11),
        Color(red: 0.13, green: 0.18, blue: 0.13),
        Color(red: 0.13, green: 0.13, blue: 0.10),
        Color(red: 0.12, green: 0.14, blue: 0.10),
        Color(red: 0.11, green: 0.14, blue: 0.11),
    ]

    private static let oceanLight: [Color] = [
        Color(red: 0.83, green: 0.96, blue: 0.99),
        Color(red: 0.83, green: 0.93, blue: 1.00),
        Color(red: 0.85, green: 0.90, blue: 1.00),
        Color(red: 0.89, green: 0.97, blue: 0.99),
        Color(red: 0.89, green: 0.95, blue: 1.00),
        Color(red: 0.91, green: 0.94, blue: 1.00),
        Color(red: 0.96, green: 0.99, blue: 0.99),
        Color(red: 0.96, green: 0.98, blue: 1.00),
        Color(red: 0.96, green: 0.97, blue: 1.00),
    ]

    private static let oceanDark: [Color] = [
        Color(red: 0.08, green: 0.19, blue: 0.26),
        Color(red: 0.08, green: 0.16, blue: 0.29),
        Color(red: 0.10, green: 0.14, blue: 0.31),
        Color(red: 0.09, green: 0.17, blue: 0.23),
        Color(red: 0.09, green: 0.15, blue: 0.25),
        Color(red: 0.11, green: 0.14, blue: 0.27),
        Color(red: 0.10, green: 0.12, blue: 0.17),
        Color(red: 0.10, green: 0.12, blue: 0.18),
        Color(red: 0.11, green: 0.12, blue: 0.19),
    ]
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
