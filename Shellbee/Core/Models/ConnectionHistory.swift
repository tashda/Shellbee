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
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ConnectionConfig].self, from: data) else {
            return
        }
        self.connections = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func add(_ config: ConnectionConfig) {
        // Remove existing duplicate (by host, port, basePath)
        connections.removeAll { $0.host == config.host && $0.port == config.port && $0.basePath == config.basePath }
        // Add to top
        connections.insert(config, at: 0)
        // Keep only top 10
        if connections.count > 10 {
            connections = Array(connections.prefix(10))
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        connections.remove(atOffsets: offsets)
        save()
    }
    
    func remove(_ config: ConnectionConfig) {
        connections.removeAll { $0 == config }
        save()
    }

    func update(_ config: ConnectionConfig) {
        if let index = connections.firstIndex(where: { $0.host == config.host && $0.port == config.port && $0.basePath == config.basePath }) {
            connections[index] = config
            save()
        }
    }

    func replace(_ original: ConnectionConfig, with updated: ConnectionConfig) {
        remove(original)
        add(updated)
    }
}
