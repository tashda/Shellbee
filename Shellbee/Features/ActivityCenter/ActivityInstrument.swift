import SwiftUI

/// The small, data-driven visual language proposed for Activity Center.
/// Kinds describe information geometry rather than individual Z2M properties,
/// so custom exposes can always fall back without inventing another icon.
enum ActivityInstrumentKind: String, CaseIterable, Identifiable, Sendable {
    case level
    case binary
    case trend
    case temperature
    case humidity
    case airQuality
    case energy
    case position
    case colour
    case signal
    case battery
    case presence
    case safety
    case action
    case network
    case health
    case backup
    case restart
    case options
    case update
    case pairing
    case group
    case touchlink
    case lifecycle
    case message
    case unknown

    var id: String { rawValue }
}

/// A named form within a kind, for properties and events that share the
/// kind's geometry but deserve their own mark (a lock is binary, but draws
/// a padlock rather than a toggle).
enum ActivityInstrumentVariant: String, CaseIterable, Sendable {
    case standard
    case fan
    case contact
    case lock
    case permitJoin
    case availability
    case rename
    case remove
}

enum ActivityInstrumentSeverity: String, CaseIterable, Sendable {
    case quiet
    case routine
    case success
    case warning
    case failure
}

enum ActivityInstrumentTrend: String, Sendable {
    case rising
    case falling
    case steady
    case none
}

struct ActivityInstrument: Sendable, Equatable {
    let kind: ActivityInstrumentKind
    let value: Double?
    let normalizedValue: Double
    let trend: ActivityInstrumentTrend
    let severity: ActivityInstrumentSeverity
    let variant: ActivityInstrumentVariant
    /// The light's actual colour for colour changes, drawn as a swatch.
    let swatch: Color?

    init(
        kind: ActivityInstrumentKind,
        value: Double? = nil,
        normalizedValue: Double = 0.5,
        trend: ActivityInstrumentTrend = .none,
        severity: ActivityInstrumentSeverity = .routine,
        variant: ActivityInstrumentVariant = .standard,
        swatch: Color? = nil
    ) {
        self.kind = kind
        self.value = value
        self.normalizedValue = min(max(normalizedValue, 0), 1)
        self.trend = trend
        self.severity = severity
        self.variant = variant
        self.swatch = swatch
    }

    var accessibilityDescription: String {
        [variant == .standard ? kind.rawValue : variant.rawValue, trend == .none ? nil : trend.rawValue, severity.rawValue]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
