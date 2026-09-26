import SwiftUI

extension ActivityInstrument {
    /// Whether a two-state instrument is in its lit state: on, open, locked,
    /// detected, alarm raised, pairing open.
    var isOn: Bool { normalizedValue >= 0.5 }

    /// Semantic colour of the mark. Severity wins for warnings and failures;
    /// otherwise the kind (and for some kinds, the value) picks the colour.
    var tint: Color {
        switch severity {
        case .failure: return .red
        case .warning: return .orange
        case .quiet: return .gray
        case .routine, .success: break
        }
        switch kind {
        case .level: return variant == .fan ? .teal : .yellow
        case .binary: return binaryTint
        case .trend, .position, .group, .vendors: return .indigo
        case .temperature:
            // Weather-app bands over -10…40 °C: under 12 °C cool, over 26 °C hot.
            if normalizedValue < 0.44 { return .cyan }
            return normalizedValue < 0.72 ? .orange : .red
        case .humidity, .backup, .update, .pairing, .models: return .blue
        case .airQuality:
            if normalizedValue < 0.34 { return .green }
            return normalizedValue < 0.67 ? .yellow : .red
        case .energy: return .yellow
        case .colour: return swatch ?? .pink
        case .signal, .network, .touchlink: return .cyan
        case .battery: return normalizedValue <= 0.2 ? .red : .green
        case .presence: return isOn ? .blue : .gray
        case .safety: return isOn ? .red : .green
        case .action: return .purple
        case .health: return .green
        case .restart: return .orange
        case .options, .message, .unknown: return .gray
        case .lifecycle:
            switch variant {
            case .rename: return .indigo
            case .remove: return .red
            default: return trend == .falling ? .orange : .green
            }
        }
    }

    private var binaryTint: Color {
        switch variant {
        case .contact: return isOn ? .blue : .gray
        case .lock: return isOn ? .teal : .orange
        default: return isOn ? .green : .gray
        }
    }
}
