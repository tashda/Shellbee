import Foundation
import OSLog

/// In-memory store for 80×80 JPEG thumbnails from the bundled device_images.lzfse resource.
/// Keyed by docKey (same key used in DocBrowserEntry and device_index.lzfse).
actor BundledImageStore {
    static let shared = BundledImageStore()

    private nonisolated let log = Logger(subsystem: "dev.echodb.shellbee", category: "BundledImageStore")
    private var images: [String: Data]?
    private var loaded = false

    private init() {}

    func imageData(for docKey: String) async -> Data? {
        if !loaded { await load() }
        return images?[docKey]
    }

    private func load() async {
        loaded = true
        let result: [String: Data]? = await Task.detached(priority: .userInitiated) {
            guard
                let url        = Bundle.main.url(forResource: "device_images", withExtension: "lzfse"),
                let compressed = try? Data(contentsOf: url),
                let data       = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
                let dict       = try? PropertyListDecoder().decode([String: Data].self, from: data)
            else { return nil }
            return dict
        }.value

        images = result
        if let images {
            log.info("Image bundle loaded: \(images.count) thumbnails")
        } else {
            log.warning("Image bundle unavailable — falling back to network for all device images")
        }
    }
}
