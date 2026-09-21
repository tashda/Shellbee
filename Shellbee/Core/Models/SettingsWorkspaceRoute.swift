import Foundation

enum SettingsWorkspaceRoute: Hashable, Identifiable {
    case bridgeOverview(UUID)
    case bridgeConnection(UUID)
    case bridgeGeneral(UUID)
    case mqtt(UUID)
    case adapter(UUID)
    case logOutput(UUID)
    case homeAssistant(UUID)
    case availability(UUID)
    case ota(UUID)
    case health(UUID)
    case network(UUID)
    case deviceFiltering(UUID)
    case touchlink(UUID)
    case backup(UUID)
    case appearance
    case homeCards
    case appGeneral
    case activityCenter
    case liveActivities
    case deviceLibrary
    case about
    case developer

    var id: String {
        "\(kind):\(bridgeID?.uuidString ?? "app")"
    }

    var bridgeID: UUID? {
        switch self {
        case .bridgeOverview(let id), .bridgeConnection(let id), .bridgeGeneral(let id),
             .mqtt(let id), .adapter(let id), .logOutput(let id), .homeAssistant(let id),
             .availability(let id), .ota(let id), .health(let id), .network(let id),
             .deviceFiltering(let id), .touchlink(let id), .backup(let id): id
        case .appearance, .homeCards, .appGeneral, .activityCenter, .liveActivities,
             .deviceLibrary, .about, .developer: nil
        }
    }

    static func reconciled(
        _ selection: SettingsWorkspaceRoute?,
        availableBridgeIDs: Set<UUID>
    ) -> SettingsWorkspaceRoute? {
        guard let selection else { return nil }
        guard let bridgeID = selection.bridgeID else { return selection }
        return availableBridgeIDs.contains(bridgeID) ? selection : nil
    }

    private var kind: String {
        switch self {
        case .bridgeOverview: "bridge-overview"
        case .bridgeConnection: "bridge-connection"
        case .bridgeGeneral: "bridge-general"
        case .mqtt: "mqtt"
        case .adapter: "adapter"
        case .logOutput: "log-output"
        case .homeAssistant: "home-assistant"
        case .availability: "availability"
        case .ota: "ota"
        case .health: "health"
        case .network: "network"
        case .deviceFiltering: "device-filtering"
        case .touchlink: "touchlink"
        case .backup: "backup"
        case .appearance: "appearance"
        case .homeCards: "home-cards"
        case .appGeneral: "app-general"
        case .activityCenter: "activity-center"
        case .liveActivities: "live-activities"
        case .deviceLibrary: "device-library"
        case .about: "about"
        case .developer: "developer"
        }
    }
}
