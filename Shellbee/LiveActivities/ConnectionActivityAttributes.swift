import ActivityKit
import Foundation

nonisolated struct ConnectionActivityAttributes: ActivityAttributes, Sendable {
    nonisolated public struct ContentState: Codable, Hashable, Sendable {
        nonisolated public enum Phase: String, Codable, Sendable {
            case connecting
            case connected
            case reconnecting
            case failed
            case cancelled
        }
        public var phase: Phase
        public var attempt: Int
        public var maxAttempts: Int
        public var message: String

        public init(phase: Phase, attempt: Int, maxAttempts: Int, message: String) {
            self.phase = phase
            self.attempt = attempt
            self.maxAttempts = maxAttempts
            self.message = message
        }
    }

    /// Hostname or IP — used as the dedup key so a reconnect to the same bridge
    /// updates the existing activity instead of stacking a new one.
    public var serverHost: String
    /// Friendly name (`ConnectionConfig.displayName`). Falls back to `serverHost`
    /// on older activities that didn't carry it.
    public var bridgeDisplayName: String

    public init(serverHost: String, bridgeDisplayName: String? = nil) {
        self.serverHost = serverHost
        self.bridgeDisplayName = bridgeDisplayName ?? serverHost
    }

    enum CodingKeys: String, CodingKey {
        case serverHost
        case bridgeDisplayName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverHost = try c.decode(String.self, forKey: .serverHost)
        bridgeDisplayName = try c.decodeIfPresent(String.self, forKey: .bridgeDisplayName) ?? serverHost
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(serverHost, forKey: .serverHost)
        try c.encode(bridgeDisplayName, forKey: .bridgeDisplayName)
    }
}
