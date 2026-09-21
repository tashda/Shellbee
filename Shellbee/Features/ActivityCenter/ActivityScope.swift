import Foundation

/// The categories in the Activity feed's category bar.
enum ActivityScope: String, CaseIterable, Identifiable {
    case all
    case needsAttention
    case devices
    case network
    case bridge

    var id: Self { self }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .needsAttention: String(localized: "Needs Attention")
        case .devices: String(localized: "Devices")
        case .network: String(localized: "Network")
        case .bridge: String(localized: "Bridge")
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        case .devices: "lightbulb.fill"
        case .network: "point.3.connected.trianglepath.dotted"
        case .bridge: "server.rack"
        }
    }

    func matches(_ entry: LogEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .needsAttention:
            return ActivityStackBuilder.needsAttention(entry)
        case .devices:
            return entry.category == .stateChange
        case .network:
            return [.deviceJoined, .deviceAnnounce, .interview, .deviceLeave, .availability]
                .contains(entry.category)
        case .bridge:
            return [.bridgeState, .permitJoin, .bridgeActivity, .general].contains(entry.category)
        }
    }
}
