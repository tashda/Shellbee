import Foundation
import SwiftUI

@Observable
final class ConnectionHistory {
    private(set) var connections: [ConnectionConfig] = []
    private(set) var defaultBridgeID: UUID?
    /// Bridges marked for auto-connect on app launch. Phase 2 multi-bridge:
    /// every bridge in this set is connected concurrently at start. If empty,
    /// the app falls back to the default bridge, then to the legacy
    /// last-successful config.
    private(set) var autoConnectIDs: Set<UUID> = []
    private let key = "connectionHistory"
    private let defaultIDKey = "savedBridges.defaultID"
    private let autoConnectKey = "savedBridges.autoConnectIDs"
    private let migrationDoneKey = "savedBridges.autoConnectMigrationDone"

    init() {
        load()
    }

    func load() {
        if let raw = UserDefaults.standard.string(forKey: defaultIDKey) {
            defaultBridgeID = UUID(uuidString: raw)
        }
        if let strings = UserDefaults.standard.array(forKey: autoConnectKey) as? [String] {
            autoConnectIDs = Set(strings.compactMap { UUID(uuidString: $0) })
        }

        guard let data = UserDefaults.standard.data(forKey: key) else {
            return
        }

        // Older payloads still decode as snapshots because extra JSON keys are ignored.
        if ConnectionConfig.containsLegacyToken(in: data),
           let legacy = try? JSONDecoder().decode([ConnectionConfig].self, from: data) {
            connections = legacy
            save()
            return
        }

        if let decoded = try? JSONDecoder().decode([ConnectionConfig.PersistedSnapshot].self, from: data) {
            let needsResave = decoded.contains { $0.idWasMinted }
            connections = decoded.map(\.connectionConfig)
            if needsResave { save() }
        }
    }

    func save() {
        let snapshots = connections.map(\.persistedSnapshot)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
        for config in connections {
            ConnectionConfig.persistToken(for: config)
        }
        if let id = defaultBridgeID, connections.contains(where: { $0.id == id }) {
            UserDefaults.standard.set(id.uuidString, forKey: defaultIDKey)
        } else {
            defaultBridgeID = nil
            UserDefaults.standard.removeObject(forKey: defaultIDKey)
        }
        // Drop auto-connect entries that no longer correspond to a saved bridge.
        let validIDs = Set(connections.map(\.id))
        autoConnectIDs.formIntersection(validIDs)
        let autoArray = autoConnectIDs.map { $0.uuidString }
        UserDefaults.standard.set(autoArray, forKey: autoConnectKey)
    }

    func isAutoConnect(_ config: ConnectionConfig) -> Bool {
        autoConnectIDs.contains(config.id)
    }

    func setAutoConnect(_ config: ConnectionConfig, _ enabled: Bool) {
        guard connections.contains(where: { $0.id == config.id }) else { return }
        if enabled {
            autoConnectIDs.insert(config.id)
        } else {
            autoConnectIDs.remove(config.id)
        }
        save()
    }

    /// Insert or update an entry. Dedup priority:
    /// 1. Same `id` → replace in place (preserves position so re-saves don't shuffle).
    /// 2. Same endpoint + name (`sameEndpoint(as:)`) → treat as a re-add of the same bridge,
    ///    preserve the existing entry's id and replace.
    /// 3. Otherwise → insert at top, trim to 10.
    func add(_ config: ConnectionConfig) {
        if let index = connections.firstIndex(where: { $0.id == config.id }) {
            connections[index] = config
            save()
            return
        }

        if let index = connections.firstIndex(where: { $0.sameEndpoint(as: config) }) {
            // Preserve the existing entry's id so external references (active session,
            // default-bridge pointer) stay valid. Move-to-front matches the legacy
            // recency semantics covered by ConnectionHistoryTests.
            var merged = config
            merged.id = connections[index].id
            connections.remove(at: index)
            connections.insert(merged, at: 0)
            save()
            return
        }

        connections.insert(config, at: 0)
        if connections.count > 10 {
            let trimmed = Array(connections.prefix(10))
            for removed in connections.suffix(connections.count - 10) {
                ConnectionConfig.removeToken(for: removed)
            }
            connections = trimmed
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        let removed = offsets.compactMap { connections.indices.contains($0) ? connections[$0] : nil }
        connections.remove(atOffsets: offsets)
        for config in removed {
            ConnectionConfig.removeToken(for: config)
        }
        save()
    }

    func remove(_ config: ConnectionConfig) {
        let removed = connections.filter { $0.id == config.id || $0.sameEndpoint(as: config) }
        connections.removeAll { $0.id == config.id || $0.sameEndpoint(as: config) }
        for entry in removed {
            ConnectionConfig.removeToken(for: entry)
        }
        save()
    }

    func update(_ config: ConnectionConfig) {
        if let index = connections.firstIndex(where: { $0.id == config.id }) {
            connections[index] = config
            save()
        }
    }

    /// Replace the original entry with a new config. Preserves the original's id
    /// so external references (active session, default pointer) remain valid even
    /// when host/port/name changed in the editor.
    func replace(_ original: ConnectionConfig, with updated: ConnectionConfig) {
        var merged = updated
        merged.id = original.id
        if let index = connections.firstIndex(where: { $0.id == original.id }) {
            // If endpoint changed, the old token is now orphaned at the old lookup key.
            if !connections[index].sameEndpoint(as: merged) {
                ConnectionConfig.removeToken(for: connections[index])
            }
            connections[index] = merged
            save()
        } else {
            add(merged)
        }
    }

    /// Move an entry to the top of the list. Used by the saved-bridges screen
    /// for explicit reordering.
    func pin(_ config: ConnectionConfig) {
        guard let index = connections.firstIndex(where: { $0.id == config.id }), index != 0 else { return }
        let entry = connections.remove(at: index)
        connections.insert(entry, at: 0)
        save()
    }

    /// Update only the human-readable name on an existing entry.
    func rename(_ config: ConnectionConfig, to newName: String?) {
        guard let index = connections.firstIndex(where: { $0.id == config.id }) else { return }
        let trimmed = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        connections[index].name = (trimmed?.isEmpty == false) ? trimmed : nil
        save()
    }

    /// Mark a saved bridge as the default — auto-connect target on app start.
    /// Pass `nil` to clear.
    func setDefault(_ config: ConnectionConfig?) {
        if let config {
            guard connections.contains(where: { $0.id == config.id }) else { return }
            defaultBridgeID = config.id
        } else {
            defaultBridgeID = nil
        }
        save()
    }

    /// The saved bridge marked as default, if any.
    var defaultBridge: ConnectionConfig? {
        guard let id = defaultBridgeID else { return nil }
        return connections.first(where: { $0.id == id })
    }

    /// One-time upgrade for users who installed the app before the
    /// auto-connect / per-bridge color UI existed. Their saved bridge is the
    /// implicit auto-connect target — without this migration they'd land on
    /// an empty UI on first launch of the new build because no bridge is
    /// flagged. We also pin the auto-assigned palette color so the editor
    /// shows the same color the rest of the app already displays.
    func performFirstLaunchMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        if connections.isEmpty, let legacy = ConnectionConfig.load() {
            connections.insert(legacy, at: 0)
        }

        var didChange = false
        for config in connections where !autoConnectIDs.contains(config.id) {
            autoConnectIDs.insert(config.id)
            didChange = true
        }
        if didChange { save() }

        for config in connections where DesignTokens.Bridge.customColorHex(for: config.id) == nil {
            DesignTokens.Bridge.setCustomColor(DesignTokens.Bridge.color(for: config.id), for: config.id)
        }

        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }
}
