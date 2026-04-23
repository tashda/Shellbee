import Foundation

@Observable
final class NotificationPreferences {
    private static let enabledKey = "notificationPreferences.enabledCategories"
    private static let overrideKey = "notificationPreferences.followLogLevelOverride"

    // Nil means "follow Z2M bridge log level"; non-nil pins preferences at
    // a fixed baseline regardless of bridge log level.
    var pinnedBaseline: NotificationCategory.DefaultLevel?

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
