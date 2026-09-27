import SwiftUI

/// The graded colours the app uses for thresholds: link quality, battery,
/// weak links on the map and the matching Needs attention lines. By default
/// they are the system green, blue, orange and red. With Themed Status Colors
/// on, a theme swaps in its own ramp, tuned so the order still reads from
/// calm to urgent and `poor` always stays a clear warning red.
nonisolated enum StatusTone: CaseIterable, Sendable {
    case excellent
    case good
    case fair
    case poor

    static let themedStorageKey = "appearance.themedStatusColors"

    var systemColor: Color {
        switch self {
        case .excellent: .green
        case .good: .blue
        case .fair: .orange
        case .poor: .red
        }
    }
}

nonisolated extension ShellbeeTheme {
    /// `nil` for `.system`, which always uses `StatusTone.systemColor`.
    func statusColor(_ tone: StatusTone) -> Color? {
        guard self != .system else { return nil }
        let hex: (light: UInt32, dark: UInt32) = switch (self, tone) {
        case (.honey, .excellent): (0x8C6A08, 0xF4B63F)
        case (.honey, .good): (0xA8936A, 0xD9C8A0)
        case (.honey, .fair): (0xCC6418, 0xF4914E)
        case (.honey, .poor): (0xB8322A, 0xF26B5E)
        case (.meadow, .excellent): (0x3B7A4B, 0x7FCB93)
        case (.meadow, .good): (0x6E8F3E, 0xB4D68C)
        case (.meadow, .fair): (0xBF7A1E, 0xEDB05A)
        case (.meadow, .poor): (0xB5403A, 0xEE7A6E)
        case (.harbor, .excellent): (0x1D6A8A, 0x66BCE0)
        case (.harbor, .good): (0x3F8C8C, 0x8DD3CF)
        case (.harbor, .fair): (0xC2782A, 0xF0B065)
        case (.harbor, .poor): (0xB8404A, 0xF07A82)
        case (.lavender, .excellent): (0x6650B0, 0xB6A5F2)
        case (.lavender, .good): (0x4F78B0, 0x9EBCF0)
        case (.lavender, .fair): (0xC07A3A, 0xEFB47A)
        case (.lavender, .poor): (0xB03E5E, 0xF07A98)
        case (.ember, .excellent): (0x6F7A36, 0xC2CC7E)
        case (.ember, .good): (0x967244, 0xDDBB8C)
        case (.ember, .fair): (0xCF8A26, 0xF2BE62)
        case (.ember, .poor): (0xA82A2A, 0xF26060)
        case (.system, _): (0, 0)
        }
        return ShellbeeTheme.Palette.dynamic(hex)
    }
}

/// Resolves a tone against the current theme and the Themed Status Colors
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
