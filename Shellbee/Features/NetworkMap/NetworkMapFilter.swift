import Foundation

enum NetworkMapFilter: String, CaseIterable, Identifiable {
    case routers = "Routers"
    case endDevices = "End Devices"
    case weakLinks = "Weak Links"
    case offline = "Offline"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .routers: "router"
        case .endDevices: "leaf"
        case .weakLinks: "exclamationmark.triangle"
        case .offline: "wifi.slash"
        }
    }

    static func matches(
        node: NetworkTopologyNode,
        filters: Set<Self>,
        isOffline: Bool,
        hasWeakLink: Bool
    ) -> Bool {
        guard !filters.isEmpty else { return true }
        let roleFilters = filters.intersection([.routers, .endDevices])
        let healthFilters = filters.intersection([.weakLinks, .offline])
        let roleMatches = roleFilters.isEmpty
            || (roleFilters.contains(.routers) && node.role == .router)
            || (roleFilters.contains(.endDevices) && node.role == .endDevice)
        let healthMatches = healthFilters.isEmpty
            || (healthFilters.contains(.weakLinks) && hasWeakLink)
            || (healthFilters.contains(.offline) && isOffline)
        return roleMatches && healthMatches
    }
}
