import SwiftUI

/// The graded colours the app uses for status: link quality, battery,
/// offline and warning states, updates, and the tint of activity marks. By
/// default they are the system green, blue, orange and red. With Themed
/// Status Colors on, a theme swaps in its own ramp, drawn from the theme's
/// family so the order still reads from calm to urgent.
nonisolated enum StatusTone: CaseIterable, Sendable {
    case excellent
    case good
    case fair
    case poor
    /// Neutral news, like an update being available. Follows the accent.
    case info

    static let themedStorageKey = "appearance.themedStatusColors"

    var systemColor: Color {
        switch self {
        case .excellent: .green
        case .good: .blue
        case .fair: .orange
        case .poor: .red
        case .info: .blue
        }
    }

    /// The tone a system status colour stands for, so views that already use
    /// `.red`, `.orange` or `.green` for state can be themed without changing
    /// what they pass. Colours that aren't status (grey, pink, a light's own
    /// colour) return `nil` and are left alone.
    init?(systemColor color: Color) {
        switch color {
        case .red: self = .poor
        case .orange, .yellow: self = .fair
        case .green, .mint: self = .excellent
        case .blue, .cyan, .teal, .indigo: self = .info
        default: return nil
        }
    }
}

nonisolated extension ShellbeeTheme {
    /// `nil` for `.system`, which always uses `StatusTone.systemColor`.
    func statusColor(_ tone: StatusTone) -> Color? {
        guard let palette else { return nil }
        if tone == .info { return palette.accent }
        let hex: (light: UInt32, dark: UInt32) = switch (self, tone) {
        case (.honey, .excellent): (0x8C6A08, 0xF4B63F)
        case (.honey, .good): (0xA8936A, 0xD9C8A0)
        case (.honey, .fair): (0xB4561C, 0xEE9A5C)
        case (.honey, .poor): (0x8E2F1C, 0xF0765A)
        case (.meadow, .excellent): (0x3B7A4B, 0x7FCB93)
        case (.meadow, .good): (0x7C9A5A, 0xB8D59A)
        case (.meadow, .fair): (0xA77A24, 0xE0B35E)
        case (.meadow, .poor): (0x9A3F2E, 0xE88070)
        case (.harbor, .excellent): (0x1D6A8A, 0x66BCE0)
        case (.harbor, .good): (0x4E8FA0, 0x9ACFDD)
        case (.harbor, .fair): (0xB07A3A, 0xE9B574)
        case (.harbor, .poor): (0x9E3B4E, 0xEE8496)
        case (.lavender, .excellent): (0x6650B0, 0xB6A5F2)
        case (.lavender, .good): (0x8A7FB8, 0xC9C0EC)
        case (.lavender, .fair): (0xB0755A, 0xEDB08F)
        case (.lavender, .poor): (0xA03C6A, 0xF07CA8)
        case (.ember, .excellent): (0x6F7A36, 0xC2CC7E)
        case (.ember, .good): (0x967244, 0xDDBB8C)
        case (.ember, .fair): (0xC07A2A, 0xEDB45E)
        case (.ember, .poor): (0x922A22, 0xF06A5A)
        default: (0, 0)
        }
        return ShellbeeTheme.Palette.dynamic(hex)
    }
}

nonisolated extension ShellbeeTheme {
    /// Series colours for categorical charts such as the device type donut:
    /// the accent, a companion from the theme's family, then grey.
    var categoricalColors: [Color] {
        guard let palette, let companion = statusColor(.fair) else { return [.blue, .orange, .gray] }
        return [palette.accent, companion, .gray]
    }
}

extension EnvironmentValues {
    /// The colour to draw for a system status colour in this environment:
    /// the theme's tone when Themed Indicators is on, otherwise unchanged.
    /// Blues stand for the accent (an update, info), so they take the
    /// theme accent whenever a theme is chosen, setting or not.
    nonisolated func themedStatusColor(_ color: Color) -> Color {
        guard let tone = StatusTone(systemColor: color),
              tone == .info || shellbeeThemesStatusColors,
              let themed = shellbeeTheme.statusColor(tone) else { return color }
        return themed
    }
}

/// A system status colour that follows Themed Indicators. Shared
/// components draw their status colours through this, so call sites keep
/// passing `.red`, `.orange` or `.green`.
nonisolated struct ThemedStatusStyle: ShapeStyle {
    let color: Color

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        environment.themedStatusColor(color).resolve(in: environment)
    }
}

extension ShapeStyle where Self == ThemedStatusStyle {
    static func themedStatus(_ color: Color) -> ThemedStatusStyle { ThemedStatusStyle(color: color) }
}

/// Resolves a tone against the current theme and the Themed Indicators
/// setting. Use it as a `ShapeStyle` (`.foregroundStyle(.status(.fair))`),
/// or `.style(...)` in a `Canvas`.
nonisolated struct StatusToneStyle: ShapeStyle {
    let tone: StatusTone

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let themed = environment.shellbeeThemesStatusColors
            ? environment.shellbeeTheme.statusColor(tone)
            : nil
        return (themed ?? tone.systemColor).resolve(in: environment)
    }
}

extension ShapeStyle where Self == StatusToneStyle {
    static func status(_ tone: StatusTone) -> StatusToneStyle { StatusToneStyle(tone: tone) }
}

nonisolated private struct ShellbeeThemesStatusColorsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    nonisolated var shellbeeThemesStatusColors: Bool {
        get { self[ShellbeeThemesStatusColorsKey.self] }
        set { self[ShellbeeThemesStatusColorsKey.self] = newValue }
    }
}
