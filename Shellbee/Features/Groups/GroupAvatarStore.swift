import Foundation

/// Persisted user choice for which group members appear in the group hero
/// avatar. Values are IEEE addresses; UserDefaults-backed and keyed by
/// group ID. Modeled as an @Observable shared store so SwiftUI views
/// re-render the moment a selection changes — UserDefaults writes alone
/// don't trigger view updates.
@Observable
final class GroupAvatarStore {
    static let shared = GroupAvatarStore()

    private var cache: [Int: [String]] = [:]

    private init() {}

    /// Reads the saved selection, lazily caching the UserDefaults value so
    /// repeated reads are cheap and observed property accesses funnel
    /// through `cache`.
    func selection(for group: Group) -> [String] {
        if let cached = cache[group.id] { return cached }
        let raw = UserDefaults.standard.stringArray(forKey: Self.key(for: group)) ?? []
        cache[group.id] = raw
        return raw
    }

    func save(_ ieees: [String], for group: Group) {
        let trimmed = Array(ieees.prefix(2))
        cache[group.id] = trimmed
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.key(for: group))
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.key(for: group))
        }
    }

    /// Resolve the device list for the avatar, given current group
    /// membership. Honors the user's selection (filtered to current
    /// members) and falls back to the first two devices when no selection
    /// or all picks have left the group.
    func resolvedDevices(for group: Group, members: [Device]) -> [Device] {
        let selected = selection(for: group)
        if !selected.isEmpty {
            let pick = selected.compactMap { ieee in members.first { $0.ieeeAddress == ieee } }
            if !pick.isEmpty { return Array(pick.prefix(2)) }
        }
        return Array(members.prefix(2))
    }

    private static func key(for group: Group) -> String { "group.avatar.\(group.id)" }
}
