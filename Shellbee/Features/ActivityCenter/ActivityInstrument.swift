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
    let primaryText: String?
    let secondaryText: String?
    let trend: ActivityInstrumentTrend
    let severity: ActivityInstrumentSeverity

    init(
        kind: ActivityInstrumentKind,
        value: Double? = nil,
        normalizedValue: Double = 0.5,
        primaryText: String? = nil,
        secondaryText: String? = nil,
        trend: ActivityInstrumentTrend = .none,
        severity: ActivityInstrumentSeverity = .routine
    ) {
        self.kind = kind
        self.value = value
        self.normalizedValue = min(max(normalizedValue, 0), 1)
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.trend = trend
        self.severity = severity
    }

    var tint: Color {
        switch severity {
        case .warning: return .orange
        case .failure: return .red
        case .success: return .green
        case .quiet: return .secondary
        case .routine:
            switch kind {
            case .network, .signal, .touchlink: return .cyan
            case .temperature, .energy, .battery: return .orange
            case .humidity, .airQuality: return .teal
            case .safety: return .red
            default: return .indigo
            }
        }
    }

    var accessibilityDescription: String {
        [kind.rawValue, primaryText, secondaryText, trend == .none ? nil : trend.rawValue, severity.rawValue]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
