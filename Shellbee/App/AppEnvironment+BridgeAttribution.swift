import Foundation

extension AppEnvironment {
    /// The bridge name for attribution badges on cards, or nil when only one
    /// bridge is saved, where the badge would say nothing new.
    func attributionBridgeName(for bridgeID: UUID) -> String? {
        guard history.connections.count >= 2 else { return nil }
        return registry.session(for: bridgeID)?.displayName
    }
}
