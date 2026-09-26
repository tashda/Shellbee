import SwiftUI

enum LogCategory: String, CaseIterable, Sendable, Hashable, ChipRepresentable {
    case general
    case stateChange
    case deviceJoined
    case deviceAnnounce
    case interview
    case deviceLeave
    /// Device went online or offline (Z2M `<device>/availability` transition).
    case availability
    /// Z2M bridge itself went online or offline.
    case bridgeState
    /// Pairing window opened or closed.
    case permitJoin
    /// Z2M bridge response/event activity that isn't a pure bridge state
    /// transition — health checks, info refresh, options updates, OTA
    /// responses, configure/rename/remove acknowledgements, touchlink
    /// scans, networkmap responses, etc. Catches every recognised
    /// `bridge/response/*` and `bridge/event` so they look like first-
    /// class log rows instead of raw MQTT topics.
    case bridgeActivity

    var chipLabel: String { label }
    var chipIcon: String? { systemImage }
    var chipTint: Color {
        switch self {
        case .stateChange: return .purple
        case .availability: return .green
        case .bridgeState: return .indigo
        case .bridgeActivity: return .indigo
        case .permitJoin: return .orange
        default: return .blue
        }
    }

    var label: String {
        switch self {
        case .general: "General"
        case .stateChange: "State Change"
        case .deviceJoined: "Device Joined"
        case .deviceAnnounce: "Device Announce"
        case .interview: "Interview"
        case .deviceLeave: "Device Left"
        case .availability: "Availability"
        case .bridgeState: "Bridge"
        case .bridgeActivity: "Bridge Activity"
        case .permitJoin: "Pairing"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "bubble.left"
        case .stateChange: "arrow.triangle.2.circlepath"
        case .deviceJoined: "dot.radiowaves.right"
        case .deviceAnnounce: "megaphone"
        case .interview: "checklist"
        case .deviceLeave: "wifi.slash"
        // wifi (without slash) sits in the same glyph family as
        // deviceLeave's wifi.slash, so the filter menu reads as a
        // related pair instead of the prior plain dot.
        case .availability: "wifi"
        case .bridgeState: "antenna.radiowaves.left.and.right"
        case .bridgeActivity: "gearshape.fill"
        case .permitJoin: "lock.open"
        }
    }
}
