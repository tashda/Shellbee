import Foundation

extension AppStore {
    func device(named friendlyName: String) -> Device? {
        devices.first { $0.friendlyName == friendlyName }
    }

    func group(named friendlyName: String) -> Group? {
        groups.first { $0.friendlyName == friendlyName }
    }

    func memberDevices(of group: Group) -> [Device] {
        group.members.compactMap { member in
            devices.first { $0.ieeeAddress == member.ieeeAddress }
        }
    }

    func state(for friendlyName: String) -> [String: JSONValue] {
        deviceStates[friendlyName] ?? [:]
    }

    func availabilityStatus(for friendlyName: String) -> DeviceAvailabilityStatus {
        if let device = device(named: friendlyName),
           device.availabilityTrackingEnabled == false
                || bridgeInfo?.config?.availabilityTrackingEnabled(for: device) == false {
            return .untracked
        }
        return (deviceAvailability[friendlyName] ?? false) ? .online : .offline
    }

    func isAvailable(_ friendlyName: String) -> Bool {
        availabilityStatus(for: friendlyName).isAvailable
    }

    func applyingConfiguredAvailability(to device: Device) -> Device {
        guard bridgeInfo?.config?.availabilityTrackingEnabled(for: device) == false else {
            return device
        }
        var updated = device
        updated.availability = .bool(false)
        return updated
    }

    func syncConfiguredAvailability() {
        devices = devices.map(applyingConfiguredAvailability)
    }

    /// Apply a rename to local state immediately so the UI updates without
    /// waiting for the bridge/devices snapshot (which can lag 3-10s after a
    /// bridge/request/device/rename). Migrates availability and state keys so
    /// the renamed device doesn't flicker through "offline".
    func optimisticRename(from: String, to: String) {
        guard from != to, !to.isEmpty else { return }
        guard let idx = devices.firstIndex(where: { $0.friendlyName == from }) else { return }
        var device = devices[idx]
        device.friendlyName = to
        devices[idx] = device

        if let availability = deviceAvailability.removeValue(forKey: from) {
            deviceAvailability[to] = availability
        }
        if let state = deviceStates.removeValue(forKey: from) {
            deviceStates[to] = state
        }
        pendingRenames.append((from: from, to: to))
    }

    func revertOptimisticRename(from: String, to: String) {
        guard let idx = devices.firstIndex(where: { $0.friendlyName == to }) else { return }
        var device = devices[idx]
        device.friendlyName = from
        devices[idx] = device

        if let availability = deviceAvailability.removeValue(forKey: to) {
            deviceAvailability[from] = availability
        }
        if let state = deviceStates.removeValue(forKey: to) {
            deviceStates[from] = state
        }
    }
}
