import Foundation

extension AppStore {
    func device(named friendlyName: String) -> Device? {
        devices.first { $0.friendlyName == friendlyName }
    }

    func state(for friendlyName: String) -> [String: JSONValue] {
        deviceStates[friendlyName] ?? [:]
    }

    func isAvailable(_ friendlyName: String) -> Bool {
        deviceAvailability[friendlyName] ?? false
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
