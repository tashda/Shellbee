import SwiftUI

/// A stored theme identity. For now themes only change Home's canvas; other
/// surfaces continue to use semantic system colors. New theme roles can be
/// resolved here without tying views to a particular palette.
nonisolated enum ShellbeeTheme: String, CaseIterable, Codable, Sendable {
    case system
    case sunriseGlow

    static let storageKey = "appearance.theme"
    static let defaultTheme: Self = .sunriseGlow

    var displayName: String {
        switch self {
        case .system: "System"
        case .sunriseGlow: "Sunrise glow"
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
        }
    }

    func accentColor(for colorScheme: ColorScheme) -> Color? {
        switch self {
        case .system: nil
        case .sunriseGlow:
            colorScheme == .dark
                ? Color(red: 0.72, green: 0.62, blue: 1.00)
                : Color(red: 0.40, green: 0.30, blue: 0.76)
        }
    }

    var swatchColors: [Color] {
        switch self {
        case .system:
            [Color(.systemGroupedBackground), Color(.secondarySystemGroupedBackground)]
        case .sunriseGlow:
            [Self.sunriseLight[0], Self.sunriseLight[2], Self.sunriseLight[5]]
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
