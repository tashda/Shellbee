import Foundation

struct BridgeInfo: Codable, Sendable, Equatable {
    let version: String
    let commit: String?
    let coordinator: CoordinatorInfo
    let network: NetworkInfo?
    let logLevel: String
    let permitJoin: Bool
    let permitJoinTimeout: Int?
    let permitJoinEnd: Int?
    /// Friendly name of the router (or coordinator) the current permit-join
    /// session is scoped to. `nil` when the network is open via all devices.
    /// Z2M doesn't include this in `bridge/info` — we capture it from the
    /// `bridge/event` `permit_join` payload and from our own outbound
    /// requests to keep the wizard honest about scope.
    let permitJoinTarget: String?
    let restartRequired: Bool
    let config: BridgeConfig?

    enum CodingKeys: String, CodingKey {
        case version, commit, coordinator, network, config
        case logLevel = "log_level"
        case permitJoin = "permit_join"
        case permitJoinTimeout = "permit_join_timeout"
        case restartRequired = "restart_required"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        commit = try container.decodeIfPresent(String.self, forKey: .commit)
        coordinator = try container.decode(CoordinatorInfo.self, forKey: .coordinator)
        network = try container.decodeIfPresent(NetworkInfo.self, forKey: .network)
        logLevel = try container.decode(String.self, forKey: .logLevel)
        permitJoin = try container.decode(Bool.self, forKey: .permitJoin)
        permitJoinTimeout = try container.decodeIfPresent(Int.self, forKey: .permitJoinTimeout)
        permitJoinTarget = nil
        restartRequired = try container.decode(Bool.self, forKey: .restartRequired)
        config = try container.decodeIfPresent(BridgeConfig.self, forKey: .config)
        
        // Calculate permitJoinEnd if timeout is present
        if let timeout = permitJoinTimeout {
            permitJoinEnd = Int(Date().timeIntervalSince1970 * 1000) + (timeout * 1000)
        } else {
            permitJoinEnd = nil
        }
    }
    
    // Also need an explicit memberwise init for Previews and AppStore updates
    init(version: String, commit: String?, coordinator: CoordinatorInfo, network: NetworkInfo?, logLevel: String, permitJoin: Bool, permitJoinTimeout: Int?, permitJoinEnd: Int?, permitJoinTarget: String? = nil, restartRequired: Bool, config: BridgeConfig?) {
        self.version = version
        self.commit = commit
        self.coordinator = coordinator
        self.network = network
        self.logLevel = logLevel
        self.permitJoin = permitJoin
        self.permitJoinTimeout = permitJoinTimeout
        self.permitJoinEnd = permitJoinEnd
        self.permitJoinTarget = permitJoinTarget
        self.restartRequired = restartRequired
        self.config = config
    }

    func copyUpdating(restartRequired: Bool? = nil, config: BridgeConfig? = nil) -> BridgeInfo {
        BridgeInfo(
            version: version,
            commit: commit,
            coordinator: coordinator,
            network: network,
            logLevel: logLevel,
            permitJoin: permitJoin,
            permitJoinTimeout: permitJoinTimeout,
            permitJoinEnd: permitJoinEnd,
            permitJoinTarget: permitJoinTarget,
            restartRequired: restartRequired ?? self.restartRequired,
            config: config ?? self.config
        )
    }

    func copyUpdatingPermitJoin(enabled: Bool, timeout: Int?, target: String?) -> BridgeInfo {
        BridgeInfo(
            version: version,
            commit: commit,
            coordinator: coordinator,
            network: network,
            logLevel: logLevel,
            permitJoin: enabled,
            permitJoinTimeout: timeout,
            permitJoinEnd: timeout.map { Int(Date().timeIntervalSince1970 * 1000) + ($0 * 1000) },
            permitJoinTarget: target,
            restartRequired: restartRequired,
            config: config
        )
    }
}

struct BridgeConfig: Codable, Sendable, Equatable {
    let mqtt: MQTTSettings?
    let frontend: FrontendSettings?
    let advanced: AdvancedConfig?
    let availability: AvailabilitySettings?
    let homeassistant: HomeAssistantSettings?
    let ota: OTASettings?
    let serial: SerialSettings?
    let health: HealthSettings?
    let passlist: [String]?
    let blocklist: [String]?
    let groups: [String: [String: JSONValue]]?

    struct AdvancedConfig: Codable, Sendable, Equatable {
        let logLevel: String?
        let lastSeen: String?
        let elapsed: Bool?
        let cacheState: Bool?
        let cacheStatePersistent: Bool?
        let cacheStateSendOnStartup: Bool?
        let output: String?
        let timestampFormat: String?
        let logDebugToMqttFrontend: Bool?
        let logRotation: Bool?
        let logDirectoriesToKeep: Int?
        let channel: Int?
        let panId: Int?
        // Extended logging
        let logOutput: [String]?
        let logDirectory: String?
        let logFile: String?
        let logConsoleJson: Bool?
        let logSymlinkCurrent: Bool?
        let logDebugNamespaceIgnore: String?
        // Network/hardware
        let adapterConcurrent: Int?
        let adapterDelay: Int?
        let transmitPower: Int?

        enum CodingKeys: String, CodingKey {
            case logLevel = "log_level"
            case lastSeen = "last_seen"
            case elapsed
            case cacheState = "cache_state"
            case cacheStatePersistent = "cache_state_persistent"
            case cacheStateSendOnStartup = "cache_state_send_on_startup"
            case output
            case timestampFormat = "timestamp_format"
            case logDebugToMqttFrontend = "log_debug_to_mqtt_frontend"
            case logRotation = "log_rotation"
            case logDirectoriesToKeep = "log_directories_to_keep"
            case channel
            case panId = "pan_id"
            case logOutput = "log_output"
            case logDirectory = "log_directory"
            case logFile = "log_file"
            case logConsoleJson = "log_console_json"
            case logSymlinkCurrent = "log_symlink_current"
            case logDebugNamespaceIgnore = "log_debug_namespace_ignore"
            case adapterConcurrent = "adapter_concurrent"
            case adapterDelay = "adapter_delay"
            case transmitPower = "transmit_power"
        }
    }
}

struct OTASettings: Codable, Sendable, Equatable {
    let updateCheckInterval: Int?
    let disableAutomaticUpdateCheck: Bool?
    let zigbeeOtaOverrideIndexLocation: String?
    let imageBlockRequestTimeout: Int?
    let imageBlockResponseDelay: Int?
    let defaultMaximumDataSize: Int?

    enum CodingKeys: String, CodingKey {
        case updateCheckInterval = "update_check_interval"
        case disableAutomaticUpdateCheck = "disable_automatic_update_check"
        case zigbeeOtaOverrideIndexLocation = "zigbee_ota_override_index_location"
        case imageBlockRequestTimeout = "image_block_request_timeout"
        case imageBlockResponseDelay = "image_block_response_delay"
        case defaultMaximumDataSize = "default_maximum_data_size"
    }
}

struct HealthSettings: Codable, Sendable, Equatable {
    let interval: Int?
    let resetOnCheck: Bool?

    enum CodingKeys: String, CodingKey {
        case interval
        case resetOnCheck = "reset_on_check"
    }
}


struct CoordinatorInfo: Codable, Sendable, Equatable {
    let type: String?
    let ieeeAddress: String?
    let meta: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, meta
        case ieeeAddress = "ieee_address"
    }
}

struct NetworkInfo: Codable, Sendable, Equatable {
    let channel: Int
    let panID: Int
    let extendedPanID: JSONValue?

    enum CodingKeys: String, CodingKey {
        case channel
        case panID = "pan_id"
        case extendedPanID = "extended_pan_id"
    }
}
