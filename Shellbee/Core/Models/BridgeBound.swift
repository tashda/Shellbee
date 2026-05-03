import Foundation

/// A `Device` paired with the bridge it came from. Used by merged-multi-bridge
/// UI to render device rows from every connected bridge in a single list while
/// keeping enough provenance (bridge id + name) to render attribution badges
/// and route mutations back to the right bridge.
///
/// `id` namespaces the underlying `ieeeAddress` by `bridgeID` so two bridges
/// with the same physical device (same IEEE) don't collide on `Identifiable`.
struct BridgeBoundDevice: Identifiable, Hashable {
    let bridgeID: UUID
    let bridgeName: String
    let device: Device

    var id: String { "\(bridgeID.uuidString):\(device.ieeeAddress)" }
}

struct BridgeBoundGroup: Identifiable, Hashable {
    let bridgeID: UUID
    let bridgeName: String
    let group: Group

    var id: String { "\(bridgeID.uuidString):\(group.id)" }
}

struct BridgeBoundLogEntry: Identifiable, Hashable {
    let bridgeID: UUID
    let bridgeName: String
    let entry: LogEntry

    var id: String { "\(bridgeID.uuidString):\(entry.id)" }
}

/// In-app notification paired with the bridge it originated from. Lets the
/// overlay show bridge attribution and route dismissal back to the originating
/// bridge's store. Equatable but not Hashable — `InAppNotification` itself
/// isn't Hashable.
struct BridgeBoundNotification: Identifiable, Equatable {
    let bridgeID: UUID
    let bridgeName: String
    let notification: InAppNotification

    var id: String { "\(bridgeID.uuidString):\(notification.id.uuidString)" }
}
