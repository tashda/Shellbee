import Foundation

struct NetworkMapCacheRecord: Codable, Equatable {
    let topology: NetworkTopology
    let updatedAt: Date
}

struct NetworkMapCache {
    static let shared = NetworkMapCache(directoryURL: defaultDirectoryURL)

    let directoryURL: URL

    func load(bridgeID: UUID) -> NetworkMapCacheRecord? {
        guard let data = try? Data(contentsOf: fileURL(for: bridgeID)) else { return nil }
        return try? JSONDecoder().decode(NetworkMapCacheRecord.self, from: data)
    }

    func save(_ record: NetworkMapCacheRecord, bridgeID: UUID) {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(record)
            try data.write(to: fileURL(for: bridgeID), options: .atomic)
        } catch {
            // A cache failure must never make the live network map unusable.
        }
    }

    private func fileURL(for bridgeID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(bridgeID.uuidString).json")
    }

    private static var defaultDirectoryURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Shellbee", isDirectory: true)
            .appendingPathComponent("NetworkMaps", isDirectory: true)
    }
}
