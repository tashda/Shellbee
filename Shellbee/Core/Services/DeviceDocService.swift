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
    private var cache: [String: DeviceDocumentation] = [:]
    private nonisolated let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    func doc(for device: Device, z2mVersion: String) async throws -> DeviceDocumentation {
        let model = device.definition?.model ?? device.modelId ?? ""
        guard !model.isEmpty else { throw DeviceDocError.unsupportedDevice }
        return try await doc(for: model, device: device, z2mVersion: z2mVersion)
    }

    func doc(for model: String, z2mVersion: String) async throws -> DeviceDocumentation {
        try await doc(for: model, vendor: "", description: "", z2mVersion: z2mVersion)
    }

    func doc(for entry: DocBrowserEntry, z2mVersion: String) async throws -> DeviceDocumentation {
        try await doc(for: entry.docKey, vendor: entry.vendor, description: entry.description, z2mVersion: z2mVersion)
    }

    func doc(for model: String, vendor: String, description: String, z2mVersion: String) async throws -> DeviceDocumentation {
        let device = Device(
            ieeeAddress: "doc-preview",
            type: .unknown,
            networkAddress: 0,
            supported: true,
            friendlyName: model,
            disabled: false,
            description: description.isEmpty ? nil : description,
            definition: DeviceDefinition(
                model: model,
                vendor: vendor,
                description: description,
                supportsOTA: false,
                exposes: [],
                options: nil,
                icon: nil
            ),
            powerSource: nil,
            modelId: model,
            manufacturer: vendor.isEmpty ? nil : vendor,
            interviewCompleted: true,
            interviewing: false,
            softwareBuildId: nil,
            dateCode: nil,
            endpoints: nil,
            options: nil
        )
        return try await doc(for: model, device: device, z2mVersion: z2mVersion)
    }

    private func doc(for model: String, device: Device, z2mVersion: String) async throws -> DeviceDocumentation {
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

        // Check the bundled snapshot before hitting the network.
        if let markdown = await BundledDocStore.shared.markdown(for: model) {
            let parsed = FrontendReferenceRewriter.rewrite(DocParser.parse(markdown))
            let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: device)
            let documentation = DeviceDocumentation(sourcePath: "devices/\(sanitized).md", parsed: parsed, normalized: normalized)
            cache[key] = documentation
            log.debug("loaded from bundle: \(key)")
            return documentation
        }

        // Fall back to the network for devices not yet in the bundle.
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
            let parsed = FrontendReferenceRewriter.rewrite(DocParser.parse(String(data: data, encoding: .utf8) ?? ""))
            let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: device)
            let documentation = DeviceDocumentation(
                sourcePath: "devices/\(sanitized).md",
                parsed: parsed,
                normalized: normalized
            )
            cache[key] = documentation
            log.debug("parsed \(parsed.sections.count) sections for \(key) via network")
            return documentation
        } catch let e as DeviceDocError {
            throw e
        } catch {
            log.error("network error for \(key): \(error)")
            throw DeviceDocError.networkError(error)
        }
    }

    func clearCache() { cache.removeAll() }
}
