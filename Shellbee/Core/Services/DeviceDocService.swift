import Foundation
import OSLog

enum DeviceDocError: Error, LocalizedError {
    case notFound
    case unsupportedDevice
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Documentation not available for this device."
        case .unsupportedDevice: return "This device doesn't have a model definition."
        case .networkError(let e): return e.localizedDescription
        }
    }
}

actor DeviceDocService {
    static let shared = DeviceDocService()

    private nonisolated let log = Logger(subsystem: "dev.echodb.shellbee", category: "DeviceDocService")
    private var cache: [String: ParsedDeviceDoc] = [:]
    private nonisolated let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    func doc(for model: String, z2mVersion: String) async throws -> ParsedDeviceDoc {
        let branch = z2mVersion.isStableZ2MVersion ? "master" : "dev"
        let key = "\(model)@\(branch)"

        log.debug("doc requested: \(key)")

        if let cached = cache[key] {
            log.debug("cache hit: \(key)")
            return cached
        }

        // Z2M multi-model filenames use underscores (e.g. E2001/E2002/E2313 → E2001_E2002_E2313.md).
        // Slashes must be replaced before percent-encoding, otherwise they become URL path separators.
        let sanitized = model.replacingOccurrences(of: "/", with: "_")
        let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sanitized
        guard let url = URL(string: "https://raw.githubusercontent.com/Koenkk/zigbee2mqtt.io/\(branch)/docs/devices/\(encoded).md") else {
            log.error("URL construction failed for: \(model)")
            throw DeviceDocError.notFound
        }

        log.debug("fetching \(url)")

        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log.debug("response \(status) for \(key), \(data.count) bytes")
            guard status == 200 else {
                throw DeviceDocError.notFound
            }
            let parsed = DocParser.parse(String(data: data, encoding: .utf8) ?? "")
            cache[key] = parsed
            log.debug("parsed \(parsed.sections.count) sections for \(key)")
            return parsed
        } catch let e as DeviceDocError {
            throw e
        } catch {
            log.error("network error for \(key): \(error)")
            throw DeviceDocError.networkError(error)
        }
    }

    func clearCache() { cache.removeAll() }
}

private extension String {
    nonisolated var isStableZ2MVersion: Bool {
        let parts = split(separator: ".")
        return parts.count == 3 && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}
