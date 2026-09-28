import Foundation
import OSLog

// MARK: - Model

struct DocBrowserEntry: Codable, Hashable, Identifiable, Sendable {
    let docKey: String
    let imageKey: String?   // image filename stem; nil on pre-existing bundles
    let model: String
    let vendor: String
    let description: String
    let exposes: [String]

    var id: String { docKey }

    var deviceType: DocDeviceType? {
        if exposes.contains("climate")  { return .thermostat }
        if exposes.contains("cover")    { return .cover }
        if exposes.contains("light")    { return .light }
        if exposes.contains("switch")   { return .switch_ }
        if exposes.contains("action")   { return .remote }
        if exposes.contains(where: { ["temperature","humidity","occupancy","contact","water_leak","presence","smoke","vibration","illuminance"].contains($0) }) { return .sensor }
        if exposes.contains(where: { ["energy","power","current"].contains($0) }) { return .energy }
        return nil
    }

    var isBatteryPowered: Bool { exposes.contains("battery") }

    var vendorInitial: String { String(vendor.prefix(1)).uppercased() }
}

enum DocDeviceType: String, CaseIterable, Identifiable {
    case light      = "Light"
    case switch_    = "Switch / Plug"
    case sensor     = "Sensor"
    case thermostat = "Thermostat"
    case cover      = "Cover / Blind"
    case remote     = "Remote / Button"
    case energy     = "Energy Meter"

    var id: String { rawValue }

    /// One device of this type, for a Type stat ("Light").
    var singularTitle: String {
        switch self {
        case .light: "Light"
        case .switch_: "Switch"
        case .sensor: "Sensor"
        case .thermostat: "Thermostat"
        case .cover: "Cover"
        case .remote: "Remote"
        case .energy: "Meter"
        }
    }

    /// A browse tile or list title ("Lights").
    var pluralTitle: String {
        switch self {
        case .light: "Lights"
        case .switch_: "Switches and plugs"
        case .sensor: "Sensors"
        case .thermostat: "Thermostats"
        case .cover: "Covers"
        case .remote: "Remotes"
        case .energy: "Energy meters"
        }
    }

    var systemImage: String {
        switch self {
        case .light:      "lightbulb.fill"
        case .switch_:    "switch.2"
        case .sensor:     "sensor.fill"
        case .thermostat: "thermometer.medium"
        case .cover:      "blinds.vertical.closed"
        case .remote:     "button.programmable"
        case .energy:     "bolt.fill"
        }
    }
}

// MARK: - Index loader

actor DocBrowserIndex {
    static let shared = DocBrowserIndex()

    private nonisolated let log = Logger(subsystem: "dev.echodb.shellbee", category: "DocBrowserIndex")
    /// One shared load, so callers that arrive while the index is still
    /// decoding wait for it instead of getting an empty list.
    private var loadTask: Task<[DocBrowserEntry], Never>?

    private init() {}

    func allEntries() async -> [DocBrowserEntry] {
        if let loadTask { return await loadTask.value }
        let task = Task { await Self.load(log: log) }
        loadTask = task
        return await task.value
    }

    private static func load(log: Logger) async -> [DocBrowserEntry] {
        let result: [DocBrowserEntry]? = await Task.detached(priority: .userInitiated) {
            guard
                let url        = Bundle.main.url(forResource: "device_index", withExtension: "lzfse"),
                let compressed = try? Data(contentsOf: url),
                let data       = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
                let list       = try? PropertyListDecoder().decode([DocBrowserEntry].self, from: data)
            else { return nil }
            return list
        }.value

        if let result {
            log.info("Device index loaded: \(result.count) entries")
        } else {
            log.warning("Device index unavailable")
        }
        return result ?? []
    }
}
