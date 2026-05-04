import Foundation

@Observable
final class NotificationPreferences {
    private static let enabledKey = "notificationPreferences.enabledCategories"
    private static let overrideKey = "notificationPreferences.followLogLevelOverride"
    private static let mutedBridgesKey = "notificationPreferences.mutedBridgeIDs"

    // Nil means "follow Z2M bridge log level"; non-nil pins preferences at
    // a fixed baseline regardless of bridge log level.
    var pinnedBaseline: NotificationCategory.DefaultLevel?

    /// Bridges the user has silenced. Notifications from a muted bridge are
    /// dropped before category filtering — disconnecting is unaffected.
    private(set) var mutedBridgeIDs: Set<UUID> = []

    private var customEnabled: Set<NotificationCategory>?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.overrideKey),
           let level = NotificationCategory.DefaultLevel(z2mLogLevel: raw) {
            pinnedBaseline = level
        }
        if let data = UserDefaults.standard.data(forKey: Self.enabledKey),
           let decoded = try? JSONDecoder().decode(Set<NotificationCategory>.self, from: data) {
            customEnabled = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.mutedBridgesKey),
           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            mutedBridgeIDs = decoded
        }
    }

    func isMuted(bridgeID: UUID) -> Bool {
        mutedBridgeIDs.contains(bridgeID)
    }

    func setMuted(_ muted: Bool, bridgeID: UUID) {
        if muted {
            mutedBridgeIDs.insert(bridgeID)
        } else {
            mutedBridgeIDs.remove(bridgeID)
        }
        if let data = try? JSONEncoder().encode(mutedBridgeIDs) {
            UserDefaults.standard.set(data, forKey: Self.mutedBridgesKey)
        }
    }

    /// Drop a bridge's mute entry. Called when the bridge is removed from
    /// saved history so stale ids don't accumulate.
    func forgetBridge(_ bridgeID: UUID) {
        guard mutedBridgeIDs.contains(bridgeID) else { return }
        setMuted(false, bridgeID: bridgeID)
    }

    /// True when the user has opted in/out manually. Used to decide whether
    /// to track the Z2M log level automatically or honour overrides.
    var hasCustomSelection: Bool { customEnabled != nil }

    func isEnabled(_ category: NotificationCategory, bridgeLogLevel: String?) -> Bool {
        if let custom = customEnabled {
            return custom.contains(category)
        }
        let baseline = pinnedBaseline
            ?? bridgeLogLevel.flatMap(NotificationCategory.DefaultLevel.init(z2mLogLevel:))
            ?? .info
        return category.defaultMinimumLogLevel <= baseline
    }

    func setEnabled(_ category: NotificationCategory, enabled: Bool, bridgeLogLevel: String?) {
        var set = customEnabled ?? defaultSet(for: bridgeLogLevel)
        if enabled { set.insert(category) } else { set.remove(category) }
        customEnabled = set
        persist()
    }

    func resetToDefaults(bridgeLogLevel: String?) {
        customEnabled = nil
        UserDefaults.standard.removeObject(forKey: Self.enabledKey)
        _ = bridgeLogLevel
    }

    private func defaultSet(for bridgeLogLevel: String?) -> Set<NotificationCategory> {
        let baseline = pinnedBaseline
            ?? bridgeLogLevel.flatMap(NotificationCategory.DefaultLevel.init(z2mLogLevel:))
            ?? .info
        return Set(NotificationCategory.allCases.filter { $0.defaultMinimumLogLevel <= baseline })
    }

    private func persist() {
        if let set = customEnabled,
           let data = try? JSONEncoder().encode(set) {
            UserDefaults.standard.set(data, forKey: Self.enabledKey)
        }
    }
}
