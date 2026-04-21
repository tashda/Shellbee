import SwiftUI

enum LogCategory: String, CaseIterable, Sendable, Hashable, ChipRepresentable {
    case general
    case stateChange
    case deviceJoined
    case deviceAnnounce
    case interview
    case deviceLeave

    var chipLabel: String { label }
    var chipIcon: String? { systemImage }
    var chipTint: Color {
        switch self {
        case .stateChange: return .purple
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
        }
    }
}
