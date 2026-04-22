import Foundation
import OSLog

/// Holds the LZFSE-compressed device_docs bundle in memory, decompressed once on first use.
/// Keyed by the same sanitized model string used in DeviceDocService (slashes → underscores).
actor BundledDocStore {
    static let shared = BundledDocStore()

    private nonisolated let log = Logger(subsystem: "dev.echodb.shellbee", category: "BundledDocStore")
    private var docs: [String: String]?
    private var loaded = false

    private init() {}

    func markdown(for model: String) async -> String? {
        if !loaded { await load() }
        let key = model.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        return docs?[key]
    }

    private func load() async {
        loaded = true
        let result: [String: String]? = await Task.detached(priority: .userInitiated) {
            guard
                let url = Bundle.main.url(forResource: "device_docs", withExtension: "lzfse"),
                let compressed = try? Data(contentsOf: url),
                let decompressed = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
                let dict = try? PropertyListDecoder().decode([String: String].self, from: decompressed)
            else {
                return nil
            }
            return dict
        }.value

        docs = result

        if let docs {
            log.info("Bundled docs loaded: \(docs.count) devices")
        } else {
            log.warning("Bundled docs unavailable — will fall back to network for all devices")
        }
    }
}
