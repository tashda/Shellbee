import Foundation

/// One device's signal and battery as Home's cards read them, with the
/// bridge it belongs to so a row can open the device. `HomeSnapshot` keys
/// state by name and merges bridges, so it can count but not link.
struct HomeDeviceReading: Identifiable, Hashable {
    let bridgeID: UUID
    let device: Device
    let linkQuality: Int?
    let battery: Int?
    let lastSeen: Date?

    var id: String { "\(bridgeID.uuidString):\(device.ieeeAddress)" }
    var route: DeviceRoute { DeviceRoute(bridgeID: bridgeID, device: device) }
    var name: String { device.friendlyName }

    /// Battery-powered devices that haven't reported for this long are
    /// probably flat rather than quiet.
    static let silentAfter: TimeInterval = 3 * 24 * 60 * 60

    var isSilent: Bool {
        guard battery != nil, let lastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) > Self.silentAfter
    }
}

extension AppEnvironment {
    /// Readings for every device Home is showing: all connected bridges
    /// when two or more are connected (as the Home cards merge them),
    /// otherwise the selected bridge. The coordinator is left out.
    func homeDeviceReadings(selectedBridgeID: UUID?) -> [HomeDeviceReading] {
        let connected = registry.orderedSessions.filter(\.isConnected)
        let sessions = connected.count >= 2
            ? connected
            : connected.filter { $0.bridgeID == selectedBridgeID }
        return sessions.flatMap { session in
            session.store.devices
                .filter { $0.type != .coordinator }
                .map { device in
                    let state = session.store.deviceStates[device.friendlyName] ?? [:]
                    return HomeDeviceReading(
                        bridgeID: session.bridgeID,
                        device: device,
                        linkQuality: state.linkQuality,
                        battery: state.battery,
                        lastSeen: state.lastSeen
                    )
                }
        }
    }
}
