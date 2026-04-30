import Foundation

/// Persisted user choice for which group members appear in the group hero
/// avatar. Values are IEEE addresses; UserDefaults-backed and keyed by
/// group ID. The resolver filters out IEEEs that are no longer members
/// and falls back to the first two devices when no selection exists or
/// none of the picked devices are still in the group.
enum GroupAvatarStore {
    static func key(for group: Group) -> String { "group.avatar.\(group.id)" }

    static func load(for group: Group) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(for: group)) ?? []
    }

    static func save(_ ieees: [String], for group: Group) {
        let trimmed = Array(ieees.prefix(2))
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(for: group))
        } else {
            UserDefaults.standard.set(trimmed, forKey: key(for: group))
        }
    }

    static func resolvedDevices(for group: Group, members: [Device]) -> [Device] {
        let selected = load(for: group)
        if !selected.isEmpty {
            let pick = selected.compactMap { ieee in members.first { $0.ieeeAddress == ieee } }
            if !pick.isEmpty { return Array(pick.prefix(2)) }
        }
        return Array(members.prefix(2))
    }
}
