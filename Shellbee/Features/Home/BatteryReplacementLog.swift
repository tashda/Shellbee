import Foundation
import Observation

/// When the user last marked a device's battery as replaced. Zigbee2MQTT
/// has no record of this, so it's kept on the phone, keyed by bridge and
/// IEEE address.
@Observable
final class BatteryReplacementLog {
    nonisolated deinit {}

    static let shared = BatteryReplacementLog()
    private static let storageKey = "batteries.replacedAt"

    @ObservationIgnored private let defaults: UserDefaults
    private var replacedAt: [String: Date]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        replacedAt = defaults.dictionary(forKey: Self.storageKey) as? [String: Date] ?? [:]
    }

    func replacedDate(for reading: HomeDeviceReading) -> Date? {
        replacedAt[reading.id]
    }

    func markReplaced(_ reading: HomeDeviceReading, on date: Date = .now) {
        replacedAt[reading.id] = date
        defaults.set(replacedAt, forKey: Self.storageKey)
    }
}
