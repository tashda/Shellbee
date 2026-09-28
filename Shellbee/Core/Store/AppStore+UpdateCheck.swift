import Foundation

/// Totals for Check All for Updates, summed across bridges.
struct OTACheckProgress: Equatable {
    let completed: Int
    let total: Int
    let failed: Int
    /// Devices with an update available on the bridges being checked.
    let found: Int

    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

extension AppStore {
    /// Devices whose state reports a firmware update available.
    var devicesWithUpdateAvailable: Int {
        devices.filter { $0.type != .coordinator && state(for: $0.friendlyName).hasUpdateAvailable }.count
    }
}
