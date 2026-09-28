import Foundation

/// Whether a screen is still waiting for data or genuinely has none. Every
/// list asks this before showing "No devices" or "No activity", so a screen
/// never claims to be empty while its bridge is still connecting.
enum BridgeDataKind {
    case devices
    case groups
    /// Activity and log lines, which only arrive once connected.
    case activity
}

extension BridgeSession {
    /// Still expecting `kind` for this connection: the bridge is connecting,
    /// or connected but hasn't sent it yet. A bridge that failed or was
    /// never connected isn't loading.
    func isLoading(_ kind: BridgeDataKind) -> Bool {
        switch connectionState {
        case .connecting, .reconnecting:
            return true
        case .connected:
            switch kind {
            case .devices, .activity: return !store.hasReceivedDevices
            case .groups: return !store.hasReceivedGroups
            }
        case .idle, .failed, .lost:
            return false
        }
    }
}

extension AppEnvironment {
    /// Any bridge still loading `kind`; pass `bridgeID` to ask about one.
    func isLoading(_ kind: BridgeDataKind, bridgeID: UUID? = nil) -> Bool {
        if let bridgeID {
            return registry.session(for: bridgeID)?.isLoading(kind) ?? false
        }
        return registry.orderedSessions.contains { $0.isLoading(kind) }
    }
}
