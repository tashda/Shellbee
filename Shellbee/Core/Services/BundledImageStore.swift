import Foundation
import OSLog
import UIKit

/// In-memory store for the device thumbnails bundled in
/// device_images.lzfse, keyed by docKey (the key device_index.lzfse uses).
///
/// The bundle is unpacked once, by a single shared task that every caller
/// awaits, so a row asking while it unpacks waits for its picture instead
/// of falling back to downloading it. Decoded images are cached so a row
/// scrolled back into view shows its picture on its first frame.
actor BundledImageStore {
    static let shared = BundledImageStore()

    private nonisolated let log = Logger(subsystem: "dev.echodb.shellbee", category: "BundledImageStore")
    private var loadTask: Task<[String: Data]?, Never>?

    /// Decoded, display-ready thumbnails. `NSCache` is thread-safe, so rows
    /// can read it synchronously while building their first frame.
    private nonisolated(unsafe) static let decoded: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()

    private init() {}

    /// A thumbnail already decoded, without waiting. `nil` if it hasn't been
    /// asked for yet or the bundle has none.
    nonisolated static func cachedImage(for docKey: String) -> UIImage? {
        decoded.object(forKey: docKey as NSString)
    }

    /// The decoded thumbnail for `docKey`, or `nil` when the bundle has none
    /// (the caller then fetches it from the network).
    func image(for docKey: String) async -> UIImage? {
        if let cached = Self.cachedImage(for: docKey) { return cached }
        guard let data = await imageData(for: docKey),
              let image = UIImage(data: data)?.preparingForDisplay() else { return nil }
        Self.decoded.setObject(image, forKey: docKey as NSString)
        return image
    }

    func imageData(for docKey: String) async -> Data? {
        await images()?[docKey]
    }

    /// Starts unpacking the bundle, e.g. behind the splash screen.
    func preload() async {
        _ = await images()
    }

    private func images() async -> [String: Data]? {
        if let loadTask { return await loadTask.value }
        let log = log
        let task = Task.detached(priority: .userInitiated) { () -> [String: Data]? in
            guard
                let url        = Bundle.main.url(forResource: "device_images", withExtension: "lzfse"),
                let compressed = try? Data(contentsOf: url),
                let data       = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
                let dict       = try? PropertyListDecoder().decode([String: Data].self, from: data)
            else {
                log.warning("Image bundle unavailable — falling back to network for all device images")
                return nil
            }
            log.info("Image bundle loaded: \(dict.count) thumbnails")
            return dict
        }
        loadTask = task
        return await task.value
    }
}
