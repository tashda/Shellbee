import Foundation
import SwiftUI

@Observable
final class ConnectionHistory {
    private(set) var connections: [ConnectionConfig] = []
    private let key = "connectionHistory"

    init() {
        load()
    }

    func load() {
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
            connections = decoded.map(\.connectionConfig)
        }
    }

    func save() {
        let snapshots = connections.map(\.persistedSnapshot)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
        for config in connections {
            ConnectionConfig.persistToken(for: config)
        }
    }

    func add(_ config: ConnectionConfig) {
        // Remove existing duplicate for the exact endpoint definition.
        connections.removeAll { matches($0, config) }
        // Add to top
        connections.insert(config, at: 0)
        // Keep only top 10
        if connections.count > 10 {
            connections = Array(connections.prefix(10))
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
        let removed = connections.filter { matches($0, config) }
        connections.removeAll { matches($0, config) }
        for entry in removed {
            ConnectionConfig.removeToken(for: entry)
        }
        save()
    }

    func update(_ config: ConnectionConfig) {
        if let index = connections.firstIndex(where: { matches($0, config) }) {
            connections[index] = config
            save()
        }
    }

    func replace(_ original: ConnectionConfig, with updated: ConnectionConfig) {
        remove(original)
        add(updated)
    }

    private func matches(_ lhs: ConnectionConfig, _ rhs: ConnectionConfig) -> Bool {
        lhs.host == rhs.host
            && lhs.port == rhs.port
            && lhs.useTLS == rhs.useTLS
            && lhs.basePath == rhs.basePath
    }
}
