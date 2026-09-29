import Foundation

/// One device's latest state and availability, observed on its own.
///
/// `AppStore.deviceStates` is a single dictionary, so a view reading it
/// redraws whenever *any* device reports. A list row reads this instead and
/// redraws only when its own device changes.
@Observable
final class DeviceLiveState {
    fileprivate(set) var state: [String: JSONValue]
    fileprivate(set) var availability: Bool?

    init(state: [String: JSONValue], availability: Bool?) {
        self.state = state
        self.availability = availability
    }
}

extension AppStore {
    /// The live handle for `friendlyName`, made on first use.
    func liveState(for friendlyName: String) -> DeviceLiveState {
        if let live = liveStates[friendlyName] { return live }
        let live = DeviceLiveState(
            state: deviceStates[friendlyName] ?? [:],
            availability: deviceAvailability[friendlyName]
        )
        liveStates[friendlyName] = live
        return live
    }

    /// Copies `friendlyName`'s entries in `deviceStates` and
    /// `deviceAvailability` to its live handle, if a view has asked for one.
    func publishLiveState(for friendlyName: String) {
        guard let live = liveStates[friendlyName] else { return }
        let state = deviceStates[friendlyName] ?? [:]
        if live.state != state { live.state = state }
        let availability = deviceAvailability[friendlyName]
        if live.availability != availability { live.availability = availability }
    }

    func publishAllLiveStates() {
        for name in liveStates.keys { publishLiveState(for: name) }
    }

    /// Like `availabilityStatus(for:)`, but reads availability from the live
    /// handle so only this device's changes invalidate the caller.
    func liveAvailabilityStatus(for friendlyName: String, live: DeviceLiveState) -> DeviceAvailabilityStatus {
        if let device = device(named: friendlyName),
           device.availabilityTrackingEnabled == false
                || bridgeInfo?.config?.availabilityTrackingEnabled(for: device) == false {
            return .untracked
        }
        return (live.availability ?? false) ? .online : .offline
    }

    /// Like `otaStatus(for:)`, but reads state from the live handle.
    func liveOTAStatus(for friendlyName: String, live: DeviceLiveState) -> OTAUpdateStatus? {
        otaUpdates[friendlyName] ?? live.state.otaUpdateStatus(for: friendlyName)
    }
}
