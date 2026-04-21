import Foundation

extension Dictionary where Key == String, Value == JSONValue {
    var otaUpdateState: String? { self["update"]?.object?["state"]?.stringValue }
    var otaProgress: Double? { self["update"]?.object?["progress"]?.numberValue }
    var otaRemaining: Int? { self["update"]?.object?["remaining"]?.intValue }
    
    var hasUpdateAvailable: Bool {
        guard otaUpdateState == "available" else { return false }

        let update = self["update"]?.object
        let installed = update?["installed_version"]?.intValue
        let latest = update?["latest_version"]?.intValue

        if let installed, let latest, installed == latest {
            return false
        }

        return true
    }

    var isUpdating: Bool { otaUpdateState == "updating" }
    var battery: Int? { self["battery"]?.intValue }
    var linkQuality: Int? { self["linkquality"]?.intValue }

    var lastSeen: Date? {
        if let epoch = self["last_seen"]?.numberValue {
            return Date(timeIntervalSince1970: epoch / 1000.0)
        }

        guard let value = self["last_seen"]?.stringValue else { return nil }
        return Self.lastSeenDate(from: value)
    }

    func otaUpdateStatus(for deviceName: String) -> OTAUpdateStatus? {
        guard let rawState = otaUpdateState else { return nil }
        guard let phase = OTAUpdateStatus.Phase(rawValue: rawState) else { return nil }

        return OTAUpdateStatus(
            deviceName: deviceName,
            phase: phase,
            progress: otaProgress,
            remaining: otaRemaining
        )
    }

    private static func lastSeenDate(from value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
