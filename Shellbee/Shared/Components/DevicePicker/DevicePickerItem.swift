import Foundation

/// A device offered by `DevicePickerSheet`, with the bridge it lives on.
struct DevicePickerItem: Identifiable, Hashable {
    let bridgeID: UUID
    let device: Device
    let isAvailable: Bool

    var id: String { "\(bridgeID.uuidString):\(device.ieeeAddress)" }
}

extension AppEnvironment {
    /// Picker items for devices on every connected bridge, or one bridge.
    func devicePickerItems(bridgeID: UUID? = nil) -> [DevicePickerItem] {
        registry.orderedSessions
            .filter { bridgeID == nil ? $0.isConnected : $0.bridgeID == bridgeID }
            .flatMap { session in
                session.store.devices
                    .filter { $0.type != .coordinator }
                    .map { DevicePickerItem(bridgeID: session.bridgeID, device: $0,
                                            isAvailable: session.store.isAvailable($0.friendlyName)) }
            }
    }
}
