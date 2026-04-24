import Foundation

/// Represents the bridge-wide settings that can be modified via `bridge/request/options`.
/// Many of these are also found in `BridgeInfo` but this struct is used for updating.
struct BridgeSettings: Codable, Sendable, Equatable {
    
    // MARK: - Main / Advanced
    var logLevel: LogLevel?
    var permitJoin: Bool?
    var lastSeen: LastSeenFormat?
    var elapsed: Bool?
    var cacheState: Bool?
    var output: OutputFormat?
    
    // MARK: - MQTT
    var mqtt: MQTTSettings?
    
    // MARK: - Frontend
    var frontend: FrontendSettings?
    
    // MARK: - Availability
    var availability: AvailabilitySettings?
    
    // MARK: - Home Assistant
    var homeassistant: HomeAssistantSettings?
    
    enum CodingKeys: String, CodingKey {
        case logLevel = "log_level"
        case permitJoin = "permit_join"
        case lastSeen = "last_seen"
        case elapsed
        case cacheState = "cache_state"
        case output
        case mqtt
        case frontend
        case availability
        case homeassistant
    }
}

extension BridgeSettings {
    enum LogLevel: String, Codable, Sendable, CaseIterable {
        case debug, info, warning, error

        var label: String {
            switch self {
            case .debug: return "Debug"
            case .info: return "Info"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }

        init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "debug": self = .debug
            case "info": self = .info
            case "warning", "warn": self = .warning
            case "error": self = .error
            default: return nil
            }
        }
    }

    enum LastSeenFormat: String, Codable, Sendable, CaseIterable {
        case disabled = "disable"
        case iso8601 = "ISO_8601"
        case iso8601Local = "ISO_8601_local"
        case epoch

        var label: String {
            switch self {
            case .disabled: return "Disabled"
            case .iso8601: return "ISO 8601 (UTC)"
            case .iso8601Local: return "ISO 8601 (Local)"
            case .epoch: return "Unix Epoch (ms)"
            }
        }
    }

    enum OutputFormat: String, Codable, Sendable, CaseIterable {
        case json
        case attribute
        case attributeAndJson = "attribute_and_json"

        var label: String {
            switch self {
            case .json: return "JSON"
            case .attribute: return "Attribute (per-topic)"
            case .attributeAndJson: return "Both"
            }
        }
    }
}

struct MQTTSettings: Codable, Sendable, Equatable {
    var server: String?
    var baseTopic: String?
    var clientID: String?
    var user: String?
    var password: String?
    var version: Int?
    var keepalive: Int?
    var ca: String?
    var cert: String?
    var key: String?
    var rejectUnauthorized: Bool?
    var includeDeviceInformation: Bool?
    var forceDisableRetain: Bool?
    var maximumPacketSize: Int?
    var qos: Int?

    enum CodingKeys: String, CodingKey {
        case server
        case baseTopic = "base_topic"
        case clientID = "client_id"
        case user, password, version, keepalive, qos
        case rejectUnauthorized = "reject_unauthorized"
        case includeDeviceInformation = "include_device_information"
        case forceDisableRetain = "force_disable_retain"
        case maximumPacketSize = "maximum_packet_size"
    }
}

struct FrontendSettings: Codable, Sendable, Equatable {
    var enabled: Bool?
    var port: Int?
    var host: String?
    var authToken: String?
    var url: String?
    var package: String?
    var sslCert: String?
    var sslKey: String?
    var baseUrl: String?
    var disableUiServing: Bool?

    enum CodingKeys: String, CodingKey {
        case enabled, port, host, url, package
        case authToken = "auth_token"
        case sslCert = "ssl_cert"
        case sslKey = "ssl_key"
        case baseUrl = "base_url"
        case disableUiServing = "disable_ui_serving"
    }
}

struct AvailabilitySettings: Codable, Sendable, Equatable {
    var enabled: Bool?
    var active: TimeoutConfig?
    var passive: TimeoutConfig?

    struct TimeoutConfig: Codable, Sendable, Equatable {
        var timeout: Int?
        var maxJitter: Int?
        var backoff: Bool?
        var pauseOnBackoffGt: Int?

        enum CodingKeys: String, CodingKey {
            case timeout
            case maxJitter = "max_jitter"
            case backoff
            case pauseOnBackoffGt = "pause_on_backoff_gt"
        }
    }
}

struct HomeAssistantSettings: Codable, Sendable, Equatable {
    var enabled: Bool?
    var discoveryTopic: String?
    var statusTopic: String?
    var legacyActionSensor: Bool?
    var experimentalEventEntities: Bool?

    enum CodingKeys: String, CodingKey {
        case enabled
        case discoveryTopic = "discovery_topic"
        case statusTopic = "status_topic"
        case legacyActionSensor = "legacy_action_sensor"
        case experimentalEventEntities = "experimental_event_entities"
    }
}

struct SerialSettings: Codable, Sendable, Equatable {
    var port: String?
    var adapter: String?
    var baudrate: Int?
    var rtscts: Bool?
    var disableLed: Bool?

    enum CodingKeys: String, CodingKey {
        case port, adapter, baudrate, rtscts
        case disableLed = "disable_led"
    }
}
